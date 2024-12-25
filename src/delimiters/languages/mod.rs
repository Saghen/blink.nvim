mod cpp;
mod csharp;
mod go;
mod java;
mod javascript;
mod lua;
mod php;
mod python;
mod ruby;
mod rust;
mod swift;
mod typescript;

pub use cpp::CppToken;
pub use csharp::CSharpToken;
pub use go::GoToken;
pub use java::JavaToken;
pub use javascript::JavaScriptToken;
pub use lua::LuaToken;
pub use php::PhpToken;
pub use python::PythonToken;
pub use ruby::RubyToken;
pub use rust::RustToken;
pub use swift::SwiftToken;
pub use typescript::TypeScriptToken;

pub enum Token {
    DelimiterOpen,
    DelimiterClose,
    LineComment,
    BlockCommentOpen,
    BlockCommentClose,
    String,
    BlockStringOpen,
    BlockStringClose,
    Escape,
    NewLine,
}

#[macro_export]
macro_rules! define_token_enum {
    ($name:ident, {
        delimiters: { $($open:literal => $close:literal),* $(,)? },
        line_comment: [ $($line_comment:literal),* $(,)? ],
        block_comment: [ $($block_comment_open:literal => $block_comment_close:literal),* $(,)? ],
        string: [ $($string_delim:literal),* $(,)? ],
        block_string: [ $($block_string_open:literal => $block_string_close:literal),* $(,)? ]
    }) => {
        #[allow(unused)] // Ignore warnings about unused variants
        #[derive(logos::Logos)]
        #[logos(skip r"[ \t\f]+")] // Skip whitespace
        pub enum $name {
            $(#[token($open)])*
            DelimiterOpen,

            $(#[token($close)])*
            DelimiterClose,

            $(#[token($line_comment)])*
            LineComment,

            $(#[token($block_comment_open)])*
            BlockCommentOpen,
            $(#[token($block_comment_close)])*
            BlockCommentClose,

            $(#[token($string_delim)])*
            String,

            $(#[token($block_string_open)])*
            BlockStringOpen,

            $(#[token($block_string_close, priority = 10)])*
            BlockStringClose,

            #[token("\\")]
            Escape,

            #[token("\n")]
            NewLine,
        }

        impl Into<$crate::delimiters::languages::Token> for $name {
            fn into(self) -> $crate::delimiters::languages::Token {
                match self {
                    Self::DelimiterOpen => $crate::delimiters::languages::Token::DelimiterOpen,
                    Self::DelimiterClose => $crate::delimiters::languages::Token::DelimiterClose,
                    Self::LineComment => $crate::delimiters::languages::Token::LineComment,
                    Self::BlockCommentOpen => $crate::delimiters::languages::Token::BlockCommentOpen,
                    Self::BlockCommentClose => $crate::delimiters::languages::Token::BlockCommentClose,
                    Self::String => $crate::delimiters::languages::Token::String,
                    Self::BlockStringOpen => $crate::delimiters::languages::Token::BlockStringOpen,
                    Self::BlockStringClose => $crate::delimiters::languages::Token::BlockStringClose,
                    Self::Escape => $crate::delimiters::languages::Token::Escape,
                    Self::NewLine => $crate::delimiters::languages::Token::NewLine,
                }
            }
        }
    };
}
