marked = require 'marked'
front = require 'yaml-front-matter'
mockquery = require 'mockquery'
loglet = require 'loglet'
path = require 'path'
_ = require 'underscore'

renderHeading = (renderer, filePath) ->
  slugify = (text) ->
    text.toLowerCase().replace(/\s+/g, '-').replace(/\W+/g, '-')
  headingIDRegex = /\s*\#*\s*\{\s*([^\s\}]+)\s*\}\s*/
  stripID = (text) ->
    text.replace headingIDRegex, ''
  baseID = (text) ->
    match = text.match headingIDRegex 
    loglet.debug 'baseID.matched', match
    if match 
      match[1].replace /^\#+/, ''
    else 
      fileID = path.basename(filePath, path.extname(filePath))
      slugify fileID + ' ' + text
  
  (text, level) ->
    text = mockquery.entities.decode text
    try 
      newText = stripID text
      id = baseID text
      element = {
        element: 'h' + level
        attributes: {id: id}
        children: [ newText ]
      }
      doc = mockquery.Document.createElement element
      html = doc.outerHTML() + '\n'
      loglet.debug 'renderer.heading', doc, text, level, newText, html
      html
    catch e
      loglet.error e

renderHTML = (renderer, options) ->
  tableCount = 0 
  tablePrefix = () ->
    if options?.prefix and options?.number 
      tableCount++
      "#{options.prefix} #{options.number}.#{tableCount} - "
    else
      ''
  (html) -> 
    $ = mockquery.load '<root>' + html + '</root>'
    $('[markdown="1"]').each (i, elt) ->
      $(elt).removeAttr 'markdown'
      inner = elt.html()
      rendered = marked inner, {renderer: renderer} # for recursive markdown parsing...
      elt.html rendered
    $('table').each (i, elt) ->
      $(elt).addClass('table')
      captions = $('caption', elt)
      if captions.length > 1 
        captions.each (i, elt) ->
          if i == 0
            $(elt).prepend tablePrefix()
          else
            $(elt).remove()
    $('root').html()

renderLink = (renderer) ->
  (href, title, text) ->
    loglet.debug 'renderer.link', href, title, text
    element = {
      element: 'a'
      attributes: {
        href: href
        title: title
      }
      children: [ ]
    }
    $ = mockquery.fromJSON(element)
    $('a').html text
    $('a').outerHTML()

renderImage = (renderer, options) ->
  count = 0
  figurePrefix = () ->
    count++
    if options?.prefix && options?.number
      options.prefix + " " + options.number + '.' + count + ' - '
    else
      ''
  (href, title, text) ->
    element = {
      element: 'figure'
      attributes: {}
      children: 
        [
          {
            element: 'img'
            attributes: { src: href }
            children: []
          }
          {
            element: 'figcaption'
            attributes: []
            children: [ ]
          }
        ]
    }
    $ = mockquery.fromJSON element
    $('figcaption').html text
    $('figcaption').prepend figurePrefix()
    $('figure').outerHTML()

renderParagraph = (renderer) ->
  dropcapRE = /^\s*<span\s+class\s*=\s"dropcap"*/i
  notInParaRE = /^\s*<\s*(figure|caption|table|thead|th|tr|td)/i
  (text) ->
    #console.log '--renderPara', text
    if text.match dropcapRE
      text
    else if text.match notInParaRE
      text
    else 
      "<p>#{text}</p>"

newRenderer = (filePath, parsed) ->
  renderer = new marked.Renderer()
  renderer.heading = renderHeading(renderer, filePath)
  renderer.html = renderHTML(renderer, if parsed.number then { number: parsed.number, prefix: 'Table'} else {})
  renderer.link = renderLink(renderer)
  renderer.image = renderImage(renderer, if parsed.number then { number: parsed.number, prefix: 'Figure' } else {})
  renderer.paragraph = renderParagraph(renderer)
  renderer

# parse will take in the file object itself... that might be the right way to do the job...  
parse = (file) ->
  parsed = _.extend file.parsed or {}, front.loadFront file.contents
  content = marked parsed.__content, renderer: newRenderer(file.path, parsed)
  parsed.__content = content
  parsed
  
module.exports = 
  parse: parse



