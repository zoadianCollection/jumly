fs = require "fs"
child_process = require "child_process"
temp = require 'temp'

_unlink = (path)->
  fs.unlink path, (err)->
    if err
      console.err "unlink: #{err}"
    #else
    #  console.log "unlink: #{path}"

_400_if_not_have = (res, str, vals)->
  unless str.toLowerCase() in vals
    res.status 400
    res.setHeader "content-type", "text/plain"
    res.write "unsupported media-type: #{str}"
    res.end()
    true

_diagrams = (jmcode, req, res)->
    temp.open "jumly", (err, info)->
      throw err if err

      fs.write info.fd, jmcode
      fs.close info.fd, (err)->
        throw err if err

        #req.headers["content-type"].match /(^[^\/]+)\/([^+]+)\+?(.*)$/
        [_, encoding, format, base64] = req.headers["accept"].match /(^[^\/]+)\/([^;]+)(;.*)?$/
        encoding = "base64" if base64 is ";base64" and encoding.match /image/i
        encoding = "html" if encoding.match(/^text$/i) and format.match(/^html$/i)
        format   = "png" if format is "*"
        encoding = "image" if encoding is "*"

        return if _400_if_not_have res, encoding, ["image", "base64", "html"]
        return if _400_if_not_have res, format, ["png", "jpg", "jpeg", "html"]

        ## jumly.sh prints tmpfile path to stdout if it creates image file
        filepath = ""
        if encoding.match /image/  ## jumly.sh prints the filepath to stdout
          stdouth = (data)-> filepath += data
        else
          stdouth = (data)-> res.write data

        ## exec jumly.sh
        proc = child_process.spawn "#{__dirname}/../bin/jumly.sh", [info.path, format, encoding]
        proc.stdout.on 'data', stdouth
        proc.stderr.on 'data', (data)-> res.write data

        proc.on 'close', (code)->
          if filepath
            fs.readFile filepath.trim(), flags:"rb", (err, data)->
              throw err if err
              res.write data
              res.end()
              _unlink info.path
              _unlink filepath.trim()
          else
            res.end()
            _unlink info.path

module.exports = (ctx)->
  b64decode: (req, res)->
    b64 = req.body.data.replace /^data:image\/png;base64,/, ""
    buf = new Buffer(b64, 'base64').toString 'binary'
    res.contentType "image/png"
    res.header "Content-Disposition", "attachment; filename=" + "diagram.png"
    res.status 201
    res.end buf, "binary"

  diagrams:
    get: (req, res)->
      res.setHeader "content-type", "image/png"
      _diagrams unescape(req.query["data"]), req, res

    post: (req, res)->
      _diagrams req.text, req, res