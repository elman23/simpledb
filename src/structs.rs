#[derive(Clone, Copy)]
pub struct FieldPair<'a> {
    key: &'a str,
    value: &'a str,
}

#[allow(dead_code)]
impl<'a> FieldPair<'a> {
    pub fn new(key: &'a str, value: &'a str) -> Self {
        Self { key, value }
    }
    pub fn key(&self) -> &'a str {
        self.key
    }
    pub fn value(&self) -> &'a str {
        self.value
    }
    pub fn set_key(&mut self, key: &'a str) {
        self.key = key;
    }
    pub fn set_value(&mut self, value: &'a str) {
        self.value = value;
    }
}
