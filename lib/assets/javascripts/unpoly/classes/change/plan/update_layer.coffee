#= require ./base

u = up.util
e = up.element

class up.Change.Plan.UpdateLayer extends up.Change.Plan

  constructor: (options) ->
    super(options)
    @parseSteps()

  preflightLayer: ->
    @options.layer

  preflightTarget: ->
    @findOld()
    return @targetWithoutPseudoClasses()

  execute: ->
    @findOld()
    @findNew()
    # Only when we have a match in the required selectors, we
    # append the optional steps for [up-hungry] elements.
    @addHungrySteps()

    promise = Promise.resolve()

    if @options.peel
      promise = promise.then => @options.layer.peel()

    historyOptions = u.only(@options, 'title', 'location')

    if @options.history && !up.browser.canPushState()
      if @options.layer.isRoot()
        up.browser.navigate(@options)
        return u.unresolvablePromise()
      else
        options.history = false

    @updateHistory(historyOptions)

    promise = promise.then =>
      swapPromises = @steps.map (step) -> @swapStep(step)

      return Promise.all(swapPromises)

    return promise

  swapStep: (step) ->
    up.puts('Swapping fragment %s', step.selector)

    # When the server responds with an error, or when the request method is not
    # reloadable (not GET), we keep the same source as before.
    if step.source == 'keep'
      step.source = up.fragment.source(step.oldElement)

    # Remember where the element came from in case someone needs to up.reload(newElement) later.
    @setSource(step.newElement, step.source)

    if step.pseudoClass
      # We're either appending or prepending. No keepable elements must be honored.

      # Text nodes are wrapped in a .up-insertion container so we can
      # animate them and measure their position/size for scrolling.
      # This is not possible for container-less text nodes.
      wrapper = e.createFromSelector('.up-insertion')
      while childNode = step.newElement.firstChild
        wrapper.appendChild(childNode)

      # Note that since we're prepending/appending instead of replacing,
      # newElement will not actually be inserted into the DOM, only its children.
      if step.pseudoClass == 'before'
        step.oldElement.insertAdjacentElement('afterbegin', wrapper)
      else
        step.oldElement.insertAdjacentElement('beforeend', wrapper)

      for child in wrapper.children
        up.hello(child, step) # emits up:fragment:inserted

      # Reveal element that was being prepended/appended.
      # Since we will animate (not morph) it's OK to allow animation of scrolling
      # if options.scrollBehavior is given.
      promise = up.viewport.scrollAfterInsertFragment(wrapper, step)

      # Since we're adding content instead of replacing, we'll only
      # animate newElement instead of morphing between oldElement and newElement
      promise = u.always(promise, up.animate(wrapper, step.transition, step))

      # Remove the wrapper now that is has served it purpose
      promise = promise.then -> e.unwrap(wrapper)

      return promise

    else if keepPlan = @findKeepPlan(step.oldElement, step.newElement, step)
      # Since we're keeping the element that was requested to be swapped,
      # there is nothing left to do here, except notify event listeners.
      up.fragment.emitKept(keepPlan)
      return Promise.resolve()

    else
      # This needs to happen before up.syntax.clean() below.
      # Otherwise we would run destructors for elements we want to keep.
      @transferKeepableElements(step)

      parent = step.oldElement.parentNode

      morphOptions = u.merge step,
        beforeStart: ->
          up.fragment.markAsDestroying(step.oldElement)
        afterInsert: =>
          up.hello(step.newElement, step)
        beforeDetach: ->
          up.syntax.clean(step.oldElement)
        afterDetach: ->
          e.remove(step.oldElement) # clean up jQuery data
          up.fragment.emitDestroyed(step.oldElement, parent: parent, log: false)

      return up.morph(step.oldElement, step.newElement, step.transition, morphOptions)

  # Returns a object detailling a keep operation iff the given element is [up-keep] and
  # we can find a matching partner in newElement. Otherwise returns undefined.
  #
  # @param {Element} options.oldElement
  # @param {Element} options.newElement
  # @param {boolean} options.keep
  # @param {boolean} options.descendantsOnly
  #
  findKeepPlan: (options) ->
    return unless options.keep

    keepable = options.oldElement
    if partnerSelector = e.booleanOrStringAttr(keepable, 'up-keep')
      u.isString(partnerSelector) or partnerSelector = '&'
      partnerSelector = e.resolveSelector(partnerSelector, keepable)
      if options.descendantsOnly
        partner = e.first(options.newElement, partnerSelector)
      else
        partner = e.subtree(options.newElement, partnerSelector)[0]
      if partner && e.matches(partner, '[up-keep]')
        plan =
          oldElement: keepable # the element that should be kept
          newElement: partner # the element that would have replaced it but now does not
          newData: up.syntax.data(partner) # the parsed up-data attribute of the element we will discard

        return plan unless up.fragment.emitKeep(plan).defaultPrevented

  # This will find all [up-keep] descendants in oldElement, overwrite their partner
  # element in newElement and leave a visually identical clone in oldElement for a later transition.
  # Returns an array of keepPlans.
  transferKeepableElements: (step) ->
    keepPlans = []
    if step.keep
      for keepable in step.oldElement.querySelectorAll('[up-keep]')
        if plan = @findKeepPlan(u.merge(step, oldElement: keepable, descendantsOnly: true))
          # plan.oldElement is now keepable

          # Replace keepable with its clone so it looks good in a transition between
          # oldElement and newElement. Note that keepable will still point to the same element
          # after the replacement, which is now detached.
          keepableClone = keepable.cloneNode(true)
          e.replace(keepable, keepableClone)

          # Since we're going to swap the entire oldElement and newElement containers afterwards,
          # replace the matching element with keepable so it will eventually return to the DOM.
          e.replace(plan.newElement, keepable)
          keepPlans.push(plan)

    step.keepPlans = keepPlans

  parseSteps: ->
    resolvedSelector = e.resolveSelector(@options.target, @options.origin)
    disjunction = u.splitValues(resolvedSelector, ',')

    @steps = disjunction.map (target, i) =>
      expressionParts = target.match(/^(.+?)(?:\:(before|after))?$/) or
        up.fail('Could not parse selector "%s"', target)

      # When extracting multiple selectors, we only want to reveal the first element.
      # So we set the { reveal } option to false for the next iteration.
      doReveal = if i == 0 then @options.reveal else false

      selector = expressionParts[1]
      if selector == 'html'
        # We cannot replace <html> with the current e.replace() implementation.
        selector = 'body'

      return u.merge @options,
        selector: selector
        pseudoClass: expressionParts[2]
        reveal: doReveal

  findOld: ->
    for step in @steps
      # Try to find fragments matchin step.selector within step.layer
      step.oldElement = up.fragment.first(step.selector, step) or @notApplicable()
    @resolveOldNesting()

  findNew: ->
    for step in @steps
      # The responseDoc has no layers.
      step.newElement = @responseDoc.first(step.selector) or @notApplicable()

  addHungrySteps: ->
    if @options.hungry
      # Find all [up-hungry] fragments within @options.layer
      hungries = up.fragment.all(up.radio.hungrySelector(), @options)
      transition = up.radio.config.hungryTransition ? @options.transition
      for hungry in hungries
        selector = e.toSelector(hungry)
        if newHungry = @responseDoc.first(selector)
          @steps.push
            selector: selector
            oldElement: hungry
            newElement: newHungry
            transition: transition
            reveal: false # we never auto-reveal a hungry element

  resolveOldNesting: ->
    return if @steps.length < 2

    compressed = u.copy(@steps)

    # When two replacements target the same element, we would process
    # the same content twice. We never want that, so we only keep the first step.
    compressed = u.uniqBy(compressed, (step) -> step.oldElement)

    compressed = u.filter compressed, (candidateStep, candidateIndex) =>
      u.every compressed, (rivalStep, rivalIndex) =>
        if rivalIndex == candidateIndex
          true
        else
          candidateElement = candidateStep.oldElement
          rivalElement = rivalStep.oldElement
          rivalStep.pseudoClass || !rivalElement.contains(candidateElement)

    # If we revealed before, we should do so now
    compressed[0].reveal = @steps[0]

    @steps = compressed

  targetWithoutPseudoClasses: ->
    u.map(@steps, 'selector').join(', ')
