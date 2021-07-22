const { unpoly, unpolyMigrate, unpolyBootstrap, specs, jasmine } = require('./entries.js')

module.exports = [
  unpoly({ es: 'es2020', min: false }),
  unpoly({ es: 'es5', min: false }),
  unpolyMigrate({ min: false }),
  unpolyBootstrap({ version: 3, min: false }),
  unpolyBootstrap({ version: 4, min: false }),
  unpolyBootstrap({ version: 5, min: false }),
  specs({ es: 'es2020', min: false }),
  specs({ es: 'es5', min: false }),
  jasmine()
]
