const { unpoly, unpolyMigrate, unpolyBootstrap } = require('./entries.js')

module.exports = [
  unpoly({ es: 'es2020', min: false }),
  unpoly({ es: 'es2020', min: true }),
  unpoly({ es: 'es5', min: false }),
  unpoly({ es: 'es5', min: true }),
  unpolyMigrate({ min: false }),
  unpolyMigrate({ min: true }),
  unpolyBootstrap({ version: 3, min: false }),
  unpolyBootstrap({ version: 3, min: true }),
  unpolyBootstrap({ version: 4, min: false }),
  unpolyBootstrap({ version: 4, min: true }),
  unpolyBootstrap({ version: 5, min: false }),
  unpolyBootstrap({ version: 5, min: true }),
]
