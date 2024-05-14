#![feature(test)]

pub mod extern_ffi {
    use nucleo::{ Matcher, Config, Utf32Str, Utf32String };
    use nucleo::pattern::{ MultiPattern, CaseMatching, Normalization };
    use lua_marshalling::LuaMarshalling;

    struct Item {
        index: u32,
        score: u32,
    }

    pub fn fuzzy(prompt: String, items: Vec<String>) -> Vec<u32> {
        // todo: change the settings so that prefix matters
        let mut config = Config::DEFAULT;
        config.prefer_prefix = true;
        let mut matcher = Matcher::new(config);

        let mut pattern = MultiPattern::new(1);
        // update the pattern with the prompt
        pattern.reparse(0, &prompt, CaseMatching::Smart, Normalization::Smart, false);

        let mut scores: Vec<Item> = vec![];
        for (idx, item) in items.iter().enumerate() {
            let item: Utf32String = item.as_str().into();
            let score = pattern.score(&[item], &mut matcher);
            scores.push(Item { index: idx as u32, score: score.unwrap_or(0) });
        }

        scores.sort_by(|a, b| b.score.cmp(&a.score));

        scores.iter().filter(|item| item.score > 0).map(|item| item.index).collect::<Vec<_>>()
    }
}

include!(concat!(env!("OUT_DIR"), "/ffi.rs"));

#[cfg(test)]
mod tests {
    extern crate test;
    use super::*;
    use test::Bencher;

    #[test]
    fn test_fuzzy() {
        let prompt = "e".to_string();
        let items = vec!["enable24".to_string(), "asd".to_string(), "wowowowe".to_string()];
        let indices = extern_ffi::fuzzy(prompt, items);
        assert_eq!(indices, vec![0, 2]);
    }

    #[bench]
    fn bench(b: &mut Bencher) {
        let items: Vec<String> = (0..1000).map(|num| num.to_string()).collect();
        b.iter(|| {
            let prompt = "4".to_string();
            let _indices = extern_ffi::fuzzy(prompt.clone(), items.clone());
        });
    }
}
