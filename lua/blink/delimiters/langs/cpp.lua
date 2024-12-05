--- @type blink.delimiters.LanguageDefinition
return {
  delimiters = {
    ['('] = ')',
    ['['] = ']',
    ['{'] = '}',
  },
  line_comment = { '//' },
  block_comment = { '/*', '*/' },
  string = { '"', "'" },
  -- TODO: handle R$prefix block strings
  block_string = {},
}
