path = require 'path'
front = require 'yaml-front-matter'
markdown = require './markdown'
jsYaml = require 'js-yaml'
loglet = require 'loglet'
mockquery = require 'mockquery'
_ = require 'underscore'
filelet = require 'filelet'
fs = require 'fs'
funclet = require 'funclet'

parseYamlFrontMatter = (data) ->
  front.loadFront data
  
parseMarkDown = (args...) ->
  markdown.parse args...

parseYaml = (data) ->
  jsYaml.safeLoad data

# this is the parse helper right here!

extendObj = (file, parsed) ->
  if parsed instanceof Array
    parsed
  else if parsed instanceof Object
    extended = _.extend file.parsed or {}, parsed
    extended
  else
    parsed

parseFile = (file) ->
  switch path.extname(file.path)
    when '.md'
      parseMarkDown file
    when '.html'
      extendObj file, eparseYamlFrontMatter file.contents
    when '.yml'
      extendObj file, parseYaml file.contents
    when '.json'
      extendObj file, JSON.parse file.contents
    else
      throw {error: 'invalid_file_type', type: path.extname(file.path), filePath: file.path, file: file}

transform = (file, cb) ->
  try 
    parsed = file.parsed = parseFile file 
    $ = 
      if file.parsed.__content
        mockquery.load file.parsed.__content
      else if file.parsed.$
        $ = mockquery.fromJSON parsed.$
        file.parsed.__content = $($.document).outerHTML()
        delete file.parsed.$
        $
      else
        throw {error: 'no_content', file: file.path}
    parentElt = $('<div />', {class: [file.parsed.template or 'chapter', 'item'].join(' ')})[0]
    if $(':root')[0].isFragment() 
      $(parentElt).append $(':root').children() 
      $.document.documentElement = parentElt
    file.$ = $
    cb null, file
  catch e
    loglet.error 'parse.transform:error', e
    cb e

cache = filelet.cache()

loadFile = (filePath, cb) ->
  cache.loadFile filePath, transform, cb

loadFiles = (filePaths, cb) ->
  cache.loadFiles filePaths, transform, cb

module.exports = 
  transform: transform
  parseFile: parseFile
  loadFile: loadFile
  loadFiles: loadFiles

