/*
// Macros for the Utility AI module.
// Would it be nicer to have them grouped with the actual code? Yes.
// Is the DM compiler dumber than a bag of extra-chonky bricks and so we cannot do that? Also yes.
*/

/* ============================================= */

// Meta-definition for compile-time-conditional logging
# ifdef UTILITYBRAIN_DEBUG_LOGGING
# define UTILITYBRAIN_DEBUG_LOG(X) to_world_log(X)
# else
# define UTILITYBRAIN_DEBUG_LOG(X)
# endif


/* ============================================= */

// Normalization scale for Activations.
// We can scale either 0 -> 1 or 0 -> 100, not sure yet what's better so we'll macro it
# define ACTIVATION_NONE 0
# define ACTIVATION_FULL 1

// Abstracting for the sake of replacing w/ less of a hack later (maybe the new `::` operator?)
# define STR_TO_PROC(procpath) text2path(procpath)


/* ============================================= */

/*
// Functions inlined for efficiency, because see top comment:
*/

// (1) Clamps input to low/high bookmarks & (2) scales the result to the slice of the bookmark interval (e.g. i=5 for lo=2, hi=8 == 50%)
# define NORMALIZE_UTILITY_INPUT(i, Lo, Hi) (ACTIVATION_FULL * ((clamp(i, Lo, Hi) - Lo) / (Hi - Lo)))

// Corrective factor calculations; we need this, otherwise multiple constraints bias scores down.
// Based on the Mike Lewis/Dave Mark lecture @ GDC15
# define UTILITY_MITIGATING_FACTOR(NumConstraints) (1 - (1 / max(1, NumConstraints || 0)))

// vvv THIS is the actual correction, the above is just a helper
# define CORRECT_UTILITY_SCORE(Score, NumConstraints) (Score + (Score * UTILITY_MITIGATING_FACTOR(NumConstraints)))

// Core utility calculation - normalize inputs, fuzz, then get an Activation response from a curve.
// e.g. UTILITY_CONSIDERATION(5, 2, 8, 0, /proc/curve_linear) => 0.5
//  or: UTILITY_CONSIDERATION(5, 2, 8, 0, /proc/curve_binary) => 0.0
//  or: UTILITY_CONSIDERATION(5, 0, 4, 0, /proc/curve_linear) => 1.0
// Note that at NoisePerc>=100, the curve inputs are dominated by noise.
# define UTILITY_CONSIDERATION(RawData, LoMark, HiMark, NoisePerc, CurveProc) call(CurveProc)(clamp(NORMALIZE_UTILITY_INPUT(RawData, LoMark, HiMark) + ((rand() - 0.5) * (NoisePerc / 50)), ACTIVATION_NONE, ACTIVATION_FULL))


/* ============================================= */

/*
// Priority weights.
//
// Raw adjusted score gets multiplied by this to get 'true' Utility.
// IOW, a fully-activated Normal action will never beat a fully-activated Urgent action
//      but a full-activation Normal may beat a weak Urgent.
*/

// If you see that, someone messed up and this action should be ignored as malformed
# define UTILITY_PRIORITY_BROKEN 0

// Ambient/idle interactions:
# define UTILITY_PRIORITY_LOW 1

// Generic 'do stuff' actions:
# define UTILITY_PRIORITY_NORMAL 2

// Important 'relaxed' actions like dealing with critical needs, or unimportant alert actions like patrolling:
# define UTILITY_PRIORITY_ELEVATED 3

// Very short-term life-or-death risk reactions, e.g. self-defense, running away:
# define UTILITY_PRIORITY_URGENT 4

// IMMEDIATE emergencies, e.g. using a Heal ability when on the last few points of HP
// There's no point in running away if you'll just bleed out in the process, after all:
# define UTILITY_PRIORITY_EMERGENCY 5

// Soft override, should be only used rarely, if ever.
// Could come up if you use a hierarchical AI, e.g. master/minion, where the master can force available actions:
# define UTILITY_PRIORITY_FORCED 100


/* ============================================= */

/* == Context Keys == */
# define CTX_KEY_POSITION "position"
# define CTX_KEY_FILTERTYPE "if_contains_type"


/* ============================================= */
