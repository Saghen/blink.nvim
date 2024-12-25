use crate::define_token_enum;

define_token_enum!(LuaToken, {
    delimiters: {
        "(" => ")",
        "[" => "]",
        "{" => "}"
    },
    line_comment: ["--"],
    block_comment: ["--[[" => "--]]"],
    string: ["\"", "'"],
    block_string: ["[[" => "]]"]
});
