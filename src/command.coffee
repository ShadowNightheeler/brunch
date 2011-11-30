path = require 'path'
yaml = require 'yaml'
fs = require 'fs'
args = require 'args'

brunch = require './brunch'
helpers = require './helpers'


exports.generateConfigPath = generateConfigPath = (appPath) ->
  if appPath?
    path.join appPath, 'config.yaml'
  else
    './config.yaml'


exports.loadConfig = loadConfig = (configPath) ->
  try
    config = (fs.readFileSync configPath).toString()
  catch error
    helpers.logError '[Brunch]: couldn\'t find config.yaml file'
    helpers.exit()
  try
    options = yaml.eval config
  catch error
    helpers.logError "[Brunch]: couldn't load config.yaml file. #{error}"
    helpers.exit()
  options


exports.parseOpts = parseOpts = (options) ->
  config = loadConfig generateConfigPath options.appPath
  helpers.extend options, config


config =
  script: 'brunch'
  commands:
    new:
      help: 'Create new brunch project'
      options:
        appPath:
          position: 1
          help: 'application path'
          metavar: 'APP_PATH'
          required: yes
        buildPath:
          abbr: 'o'
          help: 'build path'
          metavar: 'DIRECTORY'
          full: 'output'
      callback: (options) ->
        brunch.new options, ->
          brunch.build parseOpts options

    build:
      help: 'Build a brunch project'
      options:
        buildPath:
          abbr: 'o'
          help: 'build path'
          metavar: 'DIRECTORY'
          full: 'output'
        minify:
          abbr: 'm'
          flag: yes
          help: 'minify the app.js output via UglifyJS'
      callback: (options) ->
        brunch.build parseOpts options

    watch:
      help: 'Watch brunch directory and rebuild if something changed'
      options:
        buildPath:
          abbr: 'o'
          help: 'build path'
          metavar: 'DIRECTORY'
          full: 'output'
        minify:
          abbr: 'm'
          flag: yes
          help: 'minify the app.js output via UglifyJS'
      callback: (options) ->
        brunch.watch parseOpts options

    generate:
      help: 'Generate model, view or route for current project'
      options:
        generator:
          position: 1
          help: 'generator type'
          metavar: 'GENERATOR'
          choices: ['collection', 'model', 'router', 'style', 'template', 'view']
          required: yes
        name:
          position: 2
          help: 'generator class name / filename'
          metavar: 'NAME'
          required: yes
      callback: (options) ->
        brunch.generate parseOpts options

    test:
      help: 'Run tests for a brunch project'
      options:
        verbose:
          flag: yes
          help: 'set verbose option for test runner'
      callback: (options) ->
        brunch.test parseOpts options

  options:
    version:
      abbr: 'v'
      help: 'display brunch version'
      flag: yes
      callback: -> brunch.VERSION


exports.run = ->
  args.parse config
