use crate::define_token_enum;

define_token_enum!(RubyToken, {
    delimiters: {
        "(" => ")",
        "[" => "]",
        "{" => "}"
    },
    line_comment: ["#"],
    block_comment: [],
    string: ["\"", "'"],
    block_string: ["%Q{" => "}"]
});
