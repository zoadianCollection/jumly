root =
  matchers: (suite)->
    suite.addMatchers
      haveClass: (expected)->
        @actual.hasClass expected

if typeof module != 'undefined' and module.exports
  global.jasmine_matchers = root
else
  window.jasmine_matchers = root
