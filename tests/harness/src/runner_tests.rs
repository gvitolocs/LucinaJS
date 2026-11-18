//! Tests of the harness itself: which realm the gc-stress marker global is defined in.
//!
//! The marker is what lets a first-party test notice that it runs in a gc-stress build and scale
//! its loops down (see `runner::defines_gc_stress_global`). It must never reach a test262 realm:
//! a conformance result that moved because the harness put a global there would be read as an
//! engine change. The condition is a function of three inputs - the suite of the test, whether
//! the build carries the gc-stress feature, whether the full-scale override is in the environment
//! - so the whole table is checked here against a build of the harness that need not be the
//! stress one, and the effect of the two rows that matter is checked against a real realm, which
//! is what a test reads.

use brimstone_core::{
    handle_scope,
    runtime::{ContextBuilder, PropertyKey, abstract_operations::has_own_property},
};

use crate::{
    manifest::Suite,
    runner::{defines_gc_stress_global, install_gc_stress_marker},
};

/// The name the marker is defined under, as a first-party test writes it.
const MARKER: &str = "__lucinaGcStress";

/// The marker belongs to the first-party integration suite alone, and to a gc-stress build of it
/// that did not ask for full scale. Every other combination defines nothing.
#[test]
fn only_an_integration_realm_of_a_gc_stress_build_is_given_the_marker() {
    // (suite, feature on, full-scale override present) -> the marker is defined
    let table = [
        // An ordinary build defines nothing, for either suite.
        ((Suite::Integration, false, false), false),
        ((Suite::Test262, false, false), false),
        // A gc-stress build with the override set: the weekly full-scale run, plain counts.
        ((Suite::Integration, true, true), false),
        ((Suite::Test262, true, true), false),
        // A gc-stress build without it: the reduced scale the first-party gate run needs, and
        // nothing at all for test262, whose results must not depend on the harness.
        ((Suite::Integration, true, false), true),
        ((Suite::Test262, true, false), false),
    ];

    for ((suite, feature_on, full_scale_env), defined) in table {
        assert_eq!(
            defines_gc_stress_global(suite, feature_on, full_scale_env),
            defined,
            "suite {suite}, gc-stress build {feature_on}, full-scale override {full_scale_env}"
        );
    }
}

/// What the two suites see in their own realm of a gc-stress build that did not ask for full
/// scale: the integration realm has the marker, the test262 realm has nothing of it.
#[test]
fn a_test262_realm_does_not_see_the_marker_and_an_integration_realm_does() {
    assert!(
        marker_of_realm_of_a_stress_build(Suite::Integration),
        "the integration realm of a gc-stress build was left without the marker, so the first-party \
         tests would run at full scale in the gate again"
    );
    assert!(
        !marker_of_realm_of_a_stress_build(Suite::Test262),
        "a test262 realm was given the marker global, so its results depend on the harness"
    );
}

/// Whether the global object of a fresh realm of `suite`, run through the step that a gc-stress
/// build without the override takes, carries the marker.
fn marker_of_realm_of_a_stress_build(suite: Suite) -> bool {
    let cx = ContextBuilder::new().build().unwrap();
    install_gc_stress_marker(cx, suite, true, false);

    let mut cx = cx;
    let mut defined = false;
    handle_scope!(cx, {
        let name = cx.alloc_static_string(MARKER).unwrap();
        let key = PropertyKey::string_handle(cx, name).unwrap();
        let global_object = cx.initial_realm().global_object().as_object();
        defined = has_own_property(cx, global_object, key).unwrap();
    });

    cx.drop();

    defined
}
