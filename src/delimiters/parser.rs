use std::ops::RangeBounds;

use logos::{Lexer, Logos, Source};
use nvim_oxi::conversion::{Error as ConversionError, ToObject};
use nvim_oxi::serde::Serializer;
use nvim_oxi::{api::Buffer, lua, Object};
use serde::Serialize;

use super::languages::*;

#[derive(Debug, Clone, Serialize)]
pub struct Match {
    text: String,
    row: usize,
    col: usize,
    closing: Option<String>,
    stack_height: usize,
}

impl ToObject for Match {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}
impl lua::Pushable for Match {
    unsafe fn push(self, lstate: *mut lua::ffi::lua_State) -> Result<std::ffi::c_int, lua::Error> {
        self.to_object()
            .map_err(lua::Error::push_error_from_err::<Self, _>)?
            .push(lstate)
    }
}

pub fn parse_lines<R>(buffer: Buffer, line_range: R) -> Option<Vec<Vec<Match>>>
where
    R: RangeBounds<usize>,
{
    let filetype = buffer.get_option::<String>("filetype").ok()?;

    let lines = buffer.get_lines(line_range, false).ok()?;
    let mut text: String = "".to_string();
    for line in lines {
        text.push_str(&line.to_string_lossy());
        text.push('\n');
    }

    match filetype.as_str() {
        "c" => Some(parse_with_lexer(CToken::lexer(&text))),
        "cpp" => Some(parse_with_lexer(CppToken::lexer(&text))),
        "csharp" => Some(parse_with_lexer(CSharpToken::lexer(&text))),
        "go" => Some(parse_with_lexer(GoToken::lexer(&text))),
        "java" => Some(parse_with_lexer(JavaToken::lexer(&text))),
        "javascript" => Some(parse_with_lexer(JavaScriptToken::lexer(&text))),
        "lua" => Some(parse_with_lexer(LuaToken::lexer(&text))),
        "php" => Some(parse_with_lexer(PhpToken::lexer(&text))),
        "python" => Some(parse_with_lexer(PythonToken::lexer(&text))),
        "ruby" => Some(parse_with_lexer(RubyToken::lexer(&text))),
        "rust" => Some(parse_with_lexer(RustToken::lexer(&text))),
        "swift" => Some(parse_with_lexer(SwiftToken::lexer(&text))),
        "typescript" => Some(parse_with_lexer(TypeScriptToken::lexer(&text))),
        _ => None,
    }
}

fn parse_with_lexer<'a, T>(mut lexer: Lexer<'a, T>) -> Vec<Vec<Match>>
where
    T: Into<Token> + Logos<'a>,
    <T::Source as Source>::Slice<'a>: std::fmt::Display + AsRef<str>,
{
    let mut matches_by_line = vec![vec![]];
    let mut stack = vec![];

    let mut line_number = 0;
    let mut col_offset = 0;
    let mut escaped_position = None;

    while let Some(token) = lexer.next() {
        let token = match token {
            Ok(token) => token.into(),
            Err(_) => continue,
        };

        // Handle escaped characters
        if let Some((escaped_line, escaped_col)) = escaped_position {
            if !matches!(token, Token::NewLine) {
                escaped_position = None;
                let current_col = lexer.span().start;
                if line_number == escaped_line && current_col - 1 == escaped_col {
                    continue;
                }
            }
        }

        match token {
            Token::DelimiterOpen => {
                let _match = Match {
                    text: lexer.slice().to_string(),
                    row: line_number,
                    col: lexer.span().start - col_offset,
                    closing: Some(match lexer.slice().as_ref() {
                        "(" => ")".to_string(),
                        "[" => "]".to_string(),
                        "{" => "}".to_string(),
                        "<" => ">".to_string(),
                        char => char.to_string(),
                    }),
                    stack_height: stack.len(),
                };
                stack.push(_match.closing.clone().unwrap().clone());
                matches_by_line.last_mut().unwrap().push(_match);
            }

            Token::DelimiterClose => {
                if let Some(closing) = stack.last() {
                    if lexer.slice().as_ref() == closing {
                        stack.pop();
                    }
                }

                let _match = Match {
                    text: lexer.slice().to_string(),
                    row: line_number,
                    col: lexer.span().start - col_offset,
                    closing: None,
                    stack_height: stack.len(),
                };
                matches_by_line.last_mut().unwrap().push(_match);
            }

            Token::LineComment => {
                while let Some(token) = lexer.next() {
                    if let Ok(token) = token {
                        if matches!(token.into(), Token::NewLine) {
                            line_number += 1;
                            col_offset = lexer.span().start + 1;
                            matches_by_line.push(vec![]);
                            break;
                        }
                    }
                }
            }

            Token::BlockCommentOpen => {
                while let Some(token) = lexer.next() {
                    if let Ok(token) = token {
                        match token.into() {
                            Token::BlockCommentClose => break,
                            Token::NewLine => {
                                line_number += 1;
                                col_offset = lexer.span().start + 1;
                                matches_by_line.push(vec![]);
                            }
                            _ => {}
                        }
                    }
                }
            }

            Token::String => {
                let end_char = lexer.slice();
                while let Some(token) = lexer.next() {
                    if let Ok(token) = token {
                        match token.into() {
                            Token::NewLine => {
                                line_number += 1;
                                col_offset = lexer.span().start + 1;
                                matches_by_line.push(vec![]);
                                break;
                            }
                            Token::String => {
                                if lexer.slice() == end_char {
                                    break;
                                }
                            }
                            _ => {}
                        }
                    }
                }
            }

            // TODO: should also be in hot loops
            Token::Escape => {
                let col = lexer.span().start;
                escaped_position = Some((line_number, col));
            }

            Token::NewLine => {
                line_number += 1;
                col_offset = lexer.span().start + 1;
                matches_by_line.push(vec![]);
            }

            _ => {}
        }
    }

    // Remove trailing empty line
    if matches_by_line
        .last()
        .map(|matches| matches.is_empty())
        .unwrap_or(false)
    {
        matches_by_line.pop();
    }

    matches_by_line
}

pub fn recalculate_stack_heights(matches_by_line: &mut Vec<Vec<Match>>) {
    let mut stack = vec![];

    for matches in matches_by_line {
        for match_ in matches {
            match &match_.closing {
                // Opening delimiter
                Some(closing) => {
                    match_.stack_height = stack.len();
                    stack.push(closing);
                }
                // Closing delimiter
                None => {
                    if let Some(closing) = stack.last() {
                        if *closing == &match_.text {
                            stack.pop();
                        }
                    }
                    match_.stack_height = stack.len();
                }
            }
        }
    }
}
