pub mod accounting;
mod garbage_collector;
mod handle;
mod heap;
mod heap_item;
mod heap_serializer;
mod heap_trait_object;
mod heap_visitor;
mod pointer;
mod sizing;
pub(crate) mod verify;
mod weak_rules;

pub use garbage_collector::{GarbageCollector, GcType};
pub use handle::{
    Escapable, Handle, HandleContents, HandleScope, HandleScopeGuard, ToHandleContents,
};
pub use heap::{HEAP_ALIGNMENT, Heap, HeapInfo};
pub use heap_item::{
    AnyHeapItem, HeapItem, HeapItemKind, HeapUnaligned, IsHeapItem, WithHeapItemKind,
};
#[allow(unused)]
pub use heap_serializer::{HeapRootsDeserializer, HeapSerializer};
pub use heap_visitor::HeapVisitor;
pub use pointer::HeapPtr;
