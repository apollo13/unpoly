const fs = require('fs')
const { exec } = require("child_process")

let i = 0

module.exports = function(source, map, meta) {
  const inputPath = `/tmp/decaffeinate-loader-${i}.coffee`
  const outputPath = `/tmp/decaffeinate-loader-${i}.js`
  i++

  console.log("Converting...")

  fs.writeFileSync(inputPath, source)

  exec(`node_modules/.bin/decaffeinate ${inputPath} --loose --optional-chaining`, (error, stdout, stderr) => {
    if (error) {
      throw `decaffeinate error: ${error.message}`
    }
    if (stderr) {
      throw `decaffeinate stderr: ${stderr}`
    }
    let converted = fs.readFileSync(outputPath).toString()

    if (!converted) {
      throw "No converted output"
    } else {
      console.log("Converted!")
    }

    this.callback(null, converted, map, meta)

  })

  return undefined
}
