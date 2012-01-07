async = require 'async'
{exec} = require 'child_process'
fs = require 'fs'
mkdirp = require 'mkdirp'
path = require 'path'
file = require './file'
helpers = require './helpers'
testrunner = require './testrunner'

# Creates an array of languages that would be used in brunch application.
# 
# config - parsed app config
# 
# Examples
# 
#   getLanguagesFromConfig {files: {
#     'out1.js': {languages: {'\.coffee$': CoffeeScriptLanguage}}
#   # => [/\.coffee/, 'out1.js', coffeeScriptLanguage]
# 
# Returns array.
exports.getLanguagesFromConfig = getLanguagesFromConfig = (config) ->
  languages = []
  for destinationPath, settings of config.files
    for regExp, language of settings.languages
      try
        languages.push {
          regExp: ///#{regExp}///, destinationPath,
          compiler: new language config
        }
      catch error
        helpers.logError """[Brunch]: cannot parse config entry 
config.files['#{destinationPath}'].languages['#{regExp}']: #{error}.
"""
  languages
  
# Recompiles all files in current working directory.
# 
# config    - Parsed app config.
# once      - Should watcher be stopped after compiling the app first time?
# callback  - Callback that would be executed on each compilation.
# 
# 
watchFile = (config, once, callback) ->
  changedFiles = {}
  plugins = config.plugins.map (plugin) -> new plugin config
  languages = getLanguagesFromConfig config

  helpers.startServer config.port, config.buildPath if config.port
  # TODO: test if cwd has config.
  watcher = new file.FileWatcher
  writer = new file.FileWriter config
  watcher
    .add('app')
    .add('vendor')
    .on 'change', (file) ->
      languages
        .filter ({regExp}) ->
          regExp.test file
        .forEach ({compiler, destinationPath, regExp}) ->
          compiler.compile file, (error, data) ->
            if error?
              # TODO: (Coffee 1.2.1) compiler.name.
              languageName = compiler.constructor.name.replace 'Language', ''
              return helpers.logError "
[#{languageName}]: cannot compile '#{file}': #{error}"
            writer.emit 'change', {destinationPath, path: file, data}
    .on 'remove', (file) ->
      writer.emit 'remove', file
  writer.on 'error', (error) ->
    helpers.logError "[Brunch] write error. #{error}"
  writer.on 'write', (result) ->
    async.forEach plugins, (plugin, next) ->
      plugin.load next
    , (error) ->
      return helpers.logError "[Brunch]: plugin error. #{error}" if error?
      helpers.log '[Brunch]: compiled.'
      watcher.clear() if once
      callback result

# Create new application in `rootPath` and build it.
# App is created by copying directory `../template/base` to `rootPath`.
exports.new = (rootPath, buildPath, callback = (->)) ->
  templatePath = path.join __dirname, '..', 'template', 'base'
  path.exists rootPath, (exists) ->
    if exists
      return helpers.logError "[Brunch]: can\'t create project: 
directory \"#{rootPath}\" already exists"

    mkdirp rootPath, 0755, (error) ->
      return helpers.logError "[Brunch]: Error #{error}" if error?
      mkdirp buildPath, 0755, (error) ->
        return helpers.logError "[Brunch]: Error #{error}" if error?
        file.recursiveCopy templatePath, rootPath, ->
          helpers.log '[Brunch]: created brunch directory layout'
          helpers.log '[Brunch]: installing npm packages...'
          process.chdir rootPath
          exec 'npm install', (error) ->
            if error?
              helpers.logError "[Brunch]: npm error: #{error}"
              return callback error
            helpers.log '[Brunch]: installed npm package brunch-extensions'
            callback()

# Build application once and execute callback.
exports.build = (config, callback = (->)) ->
  watchFile config, yes, callback

# Watch application for changes and execute callback on every compilation.
exports.watch = (config, callback = (->)) ->
  watchFile config, no, callback

# Generate new controller / model / view and its tests.
# 
# type - one of: collection, model, router, style, view
# name - filename.
# 
# Examples
# 
#   generate 'style', 'user'
#   generate 'view', 'user'
#   generate 'collection', 'users'
# 
exports.generate = (type, name, callback = (->)) ->
  extension = switch type
    when 'style' then 'styl'
    when 'template' then 'eco'
    else 'coffee'
  filename = "#{name}.#{extension}"
  filePath = path.join 'app', "#{type}s", filename
  data = switch extension
    when 'coffee'
      genName = helpers.capitalize type
      className = helpers.formatClassName name
      "class exports.#{className} extends Backbone.#{genName}\n"
    else
      ''

  fs.writeFile filePath, data, (error) ->
    return helpers.logError error if error?
    helpers.log "Generated #{filePath}"
    callback()
