u = up.util

class up.ExtractCascade

  BODY_TARGET_PATTERN = /(^|\s|,)(body|html)(,|\s|$)/i

  constructor: (options) ->
    @options = u.options(options)
    @options.target = e.resolveSelector(@options.target, @options.origin)
    @options.hungry ?= true
    @options.keep ?= true
    @options.layer ?= @defaultLayerOption()

    throw "should @options.peel be a default? or only for user-clicks?"

    @buildPlans()

  defaultLayerOption: ->
    if @options.flavor
      # Allow users to omit [up-layer=new] if they provide [up-dialog]
      'new'
    else if @options.origin
      # Links update their own layer by default.
      'origin'
    else
      # If no origin is given, we assume the highest layer.
      'current'

  buildPlans: ->
    @plans = []
    if @options.layer == 'new'
      layerFallbacks = up.layer.fallbackTargets(@options.flavor)
      @eachTargetCandidatePlan layerFallbacks, (plan) =>
        # We cannot open a <body> in a new layer
        unless @targetsBody(plan)
          @plans.push(new up.ExtractPlan.OpenLayer(plan))

    else
      for layer in up.layer.resolve(@options.layer)
        layerFallbacks = layer.fallbackTargets()
        @eachTargetCandidatePlan layerFallbacks, (plan) =>
          @plans.push(new up.ExtractPlan.UpdateLayer, { plan })

    # Make sure we always succeed
    @plans.push(new ExtractPlan.ResetWorld(@options))

  @eachTargetCandidatePlan: (layerFallbacks, planOptions, fn) ->
    for targetCandidate, i in @buildTargetCandidates(layerFallbacks)
      # Since the last plan is always SwapBody, we don't need to
      # add other plans that would also swap the body.
      continue if @targetsBody(targetCandidate)

      plan = u.options(planOptions, @options)
      plan.target = targetCandidate

      if i > 0
        # If we're using a fallback (any candidate that's not the first),
        # the original transition might no longer be appropriate.
        plan.transition = up.fragment.config.fallbackTransition ? @options.transition

      fn(plan)

  targetsBody: (plan) ->
    BODY_TARGET_PATTERN.test(plan.target)

  buildTargetCandidates: (layerFallbacks) ->
    targetCandidates = [@options.target, @options.fallback, layerFallbacks]
    # Remove undefined, null and { fallback: false } from the list
    targetCandidates = u.filter(targetCandidates, u.isTruthy)
    targetCandidates = u.flatten(targetCandidates)
    targetCandidates = u.uniq(targetCandidates)

    if @options.fallback == false || @options.content
      # Use the first defined candidate, but not @target (which might be missing)
      targetCandidates = [targetCandidates[0]]

    targetCandidates

  execute: ->
    @buildResponseDoc()

    unless @options.saveScroll == false
      up.viewport.saveScroll()

    if up.fragment.shouldExtractTitle(@options) && responseTitle = @responseDoc.title()
      @options.title = responseTitle

    @seekPlan
      attempt: (plan) -> plan.execute()
      noneApplicable: => @executeNotApplicable()

  executeNotApplicable: ->
    if @options.inspectResponse
      inspectAction = { label: 'Open response', callback: @options.inspectResponse }
    up.fail("Could not match #{@options.humanizedTarget} in current page and response", action: inspectAction)

  buildResponseDoc: ->
    @responseDoc = new up.ResponseDoc

  preflightTarget: ->
    @seekPlan
      attempt: (plan) -> plan.preflightTarget()
      noneApplicable: => @preflightTargetNotApplicable()

  preflightTargetNotApplicable: ->
    up.fail("Could not find #{@options.humanizedTarget} in current page")

  seekPlan: (opts) ->
    for plan, index in @plans
      try
        opts.attempt(plan)
      catch e
        if e == up.ExtractPlan.NOT_APPLICABLE
          if index < @plans.length - 1
            # Retry with next plan
          else
            # No next plan to try
            opts.noneApplicable()
        else
          # Any other exception is re-thrown
          throw e

#  @forOptions: (options) ->
#    options.extractCascade ||= new @(options)
#
#  @execute: (options, responseDoc) ->
#    @forOptions(options).execute(responseDoc)
#
#  @preflightTarget: (options) ->
#    @forOptions(options).preflightTarget()
#
#  @preflightLayer: (options) ->
#    @forOptions(options).preflightLayer()
