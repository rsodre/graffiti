use graffiti::utils::constants::{
    SLASH, QUESTION_MARK, AMPERSAND, EQUALS, PERCENT, ZERO
};


#[derive(Drop)]
pub struct UrlBuilder {
    pub url: ByteArray,
    pub data: Array<Parameter>
}

impl UrlBuilderDefault of Default<UrlBuilder> {
    fn default() -> UrlBuilder {
        UrlBuilder { url: "", data: array![] }
    }
}


#[derive(Drop)]
pub struct Parameter {
    pub name: ByteArray,
    pub value: ByteArray,
    pub escape: bool,
}

trait ParameterTrait<Parameter> {
    fn to_bytes(self: Parameter, first: bool) -> ByteArray;
}

impl ParameterImpl of ParameterTrait<Parameter> {
    fn to_bytes(mut self: Parameter, first: bool) -> ByteArray {
        let mut ba1: ByteArray = Default::default();

        ba1.append_word(if first { QUESTION_MARK } else { AMPERSAND }, 1);
        ba1.append(@self.name);
        ba1.append_word(EQUALS, 1);
        if (self.escape) {
            // ECMA-262 - 15.1.3.4
            // based on: https://chromium.googlesource.com/v8/v8/+/3.26.4/src/uri.js#359
            let mut i = 0_usize;
            while (i < self.value.len()) {
                let cc: u8 = self.value.at(i).unwrap();
                if (
                    (97 <= cc && cc <= 122) || // a - z
                    (65 <= cc && cc <= 90) || // A - Z
                    (48 <= cc && cc <= 57) || // 0 - 9
                    cc == 33 || // !
                    (39 <= cc && cc <= 42) || // '()*
                    (45 <= cc && cc <= 46) || // -.
                    cc == 95 || // _
                    cc == 126 // ~
                ) {
                    ba1.append_word(cc.into(), 1);
                } else {
                    ba1.append_word(PERCENT, 1);
                    if (cc < 16) {
                        ba1.append_word(ZERO, 1);
                    }
                    ba1.append(@format!("{:x}", cc));
                }
                i += 1;
            };
        } else {
            ba1.append(@self.value);
        }
        ba1
    }
}

trait Builder<T> {
    fn new(url: ByteArray) -> T;
    fn add(self: T, name: ByteArray, value: ByteArray, escape: bool) -> T;
    fn add_if_some(self: T, name: ByteArray, value: Option<ByteArray>, escape: bool) -> T;
    fn add_if_not_null(self: T, name: ByteArray, value: ByteArray, escape: bool) -> T;
    fn build(self: T) -> ByteArray;
}


pub impl UrlImpl of Builder<UrlBuilder> {
    fn new(url: ByteArray) -> UrlBuilder {
        UrlBuilder { url, data: array![] }
    }

    fn add(mut self: UrlBuilder, name: ByteArray, value: ByteArray, escape: bool) -> UrlBuilder {
        self.data.append(Parameter { name, value, escape });
        self
    }

    fn add_if_some(mut self: UrlBuilder, name: ByteArray, value: Option<ByteArray>, escape: bool) -> UrlBuilder {
        match value {
            Option::Some(v) => {
                self.data.append(Parameter { name, value: v, escape });
            },
            Option::None => {}
        };
        self
    }

    fn add_if_not_null(mut self: UrlBuilder, name: ByteArray, value: ByteArray, escape: bool) -> UrlBuilder {
        if value.len() > 0 {
            self.data.append(Parameter { name, value, escape });
        }
        self
    }

    fn build(mut self: UrlBuilder) -> ByteArray {
        let mut ba1 = self.url;

        ba1.append_word(SLASH, 1);

        let mut first = true;
        loop {
            match self.data.pop_front() {
                Option::Some(attr) => {
                    ba1.append(@attr.to_bytes(first));
                },
                Option::None => { break; },
            };
            first = false;
        };

        ba1
    }
}

#[cfg(test)]
mod tests {
    use super::UrlImpl;

    fn URL() -> ByteArray {
        "https://example.com"
    }

    #[test]
    fn test_add() {
        let data = UrlImpl::new(URL())
            .add("name", "Token 1234", true)
            .add("unescaped", "!'()*-._~", true)
            .add("escaped", ";/?:@&=+$,#", true)
            .build();
        // assert_eq!(data, "https://example.com/?name=Token%201234&unescaped=!'()*-._~&escaped=%3B%2F%3F%3A%40%26%3D%2B%24%2C%23");
        assert_eq!(data, "https://example.com/?name=Token%201234&unescaped=!'()*-._~&escaped=%3b%2f%3f%3a%40%26%3d%2b%24%2c%23");
        println!("url: {}", data);
    }

    #[test]
    fn test_add_if_some() {
        let data = UrlImpl::new(URL())
            .add_if_some("attr1", Option::None, false)
            .build();
        assert_eq!(data, format!("{}/", URL()));
        let data = UrlImpl::new(URL())
            .add_if_some("attr1", Option::Some("1234"), false)
            .add_if_some("attr2", Option::None, false)
            .build();
        assert_eq!(data, format!("{}/?attr1=1234", URL()));
        let data = UrlImpl::new(URL())
            .add_if_some("attr1", Option::Some("1234"), false)
            .add_if_some("attr2", Option::Some("5678"), false)
            .build();
        assert_eq!(data, format!("{}/?attr1=1234&attr2=5678", URL()));
    }

    #[test]
    fn test_add_if_not_null() {
        let data = UrlImpl::new(URL())
            .add_if_not_null("attr1", "", false)
            .build();
        assert_eq!(data, format!("{}/", URL()));
        let data = UrlImpl::new(URL())
            .add_if_not_null("attr1", "1234", false)
            .add_if_not_null("attr2", "", false)
            .build();
        assert_eq!(data, format!("{}/?attr1=1234", URL()));
         let data = UrlImpl::new(URL())
            .add_if_not_null("attr1", "1234", false)
            .add_if_not_null("attr2", "5678", false)
            .build();
        assert_eq!(data, format!("{}/?attr1=1234&attr2=5678", URL()));
    }

}
