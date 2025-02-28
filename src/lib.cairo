trait ToBytes<T> {
    fn to_bytes(self: T) -> ByteArray;
}

pub mod elements;
// use elements::{Tag, TagImpl};

pub mod json;
pub mod utils;