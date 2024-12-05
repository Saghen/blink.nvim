-- TODO: doesn't handle r##"string"##

--- @type blink.delimiters.LanguageDefinition
return {
  delimiters = {
    ['('] = ')',
    ['['] = ']',
    ['{'] = '}',
  },
  line_comment = { '//' },
  block_comment = { '/*', '*/' },
  string = { "'" },
  block_string = { '"', '"' },
}
