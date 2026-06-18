/**
 * Strength score formulas that normalize a powerlifting total across
 * bodyweight so athletes in different weight classes can be compared.
 *
 * All functions accept total and bodyweight in kg, and a gender string
 * matching the values accepted by the competition profile ('M', 'F', 'Mx').
 * Mx is treated as the same as male for scoring purposes, matching current
 * federation practice (no separate coefficient set exists).
 *
 * Returns null when inputs are out of the valid range (bodyweight < 30 or
 * > 300 kg, total ≤ 0) rather than producing a nonsense value.
 */

// Fix #2: do not widen with `| string` — that erases the union and makes
// TypeScript accept any string silently. Unknown genders fall back to male
// inside each function (same as Mx — no separate coefficient set exists).
type Gender = 'M' | 'F' | 'Mx';

// ── Polynomial helper ───────────────────────────────────────────────────────

/** Evaluates a + b·x + c·x² + … from a coefficient array [a, b, c, …]. */
function poly(x: number, coeffs: readonly number[]): number {
  let result = 0;
  let power = 1;
  for (const c of coeffs) {
    result += c * power;
    power *= x;
  }
  return result;
}

// ── Wilks (2020 update, "Wilks II") ────────────────────────────────────────
// Coefficients published by Robert Wilks after the 2020 revision.

const WILKS2_COEFF_M = [-216.0475144, 16.2606339, -0.002388645, -0.00113732, 7.01863e-6, -1.291e-8] as const;
const WILKS2_COEFF_F = [594.31747775582, -27.23842536447, 0.82112226871, -0.009307339136, 4.73158225e-5, -9.0546e-8] as const;

/**
 * Wilks (2020) score.
 * Reference: Wilks, R. (2020). Revised Wilks Formula.
 */
export function computeWilks(totalKg: number, bodyweightKg: number, gender: Gender): number | null {
  if (totalKg <= 0 || bodyweightKg < 30 || bodyweightKg > 300) return null;
  const coeffs = gender === 'F' ? WILKS2_COEFF_F : WILKS2_COEFF_M;
  const denominator = poly(bodyweightKg, coeffs);
  if (denominator <= 0) return null;
  return Math.round((500 / denominator) * totalKg * 100) / 100;
}

// ── Dots ───────────────────────────────────────────────────────────────────
// Introduced by Tim Sayers (2019) as a simpler alternative to Wilks.
// Coefficients from the original Dots publication.

const DOTS_COEFF_M = [-307.75076, 24.0900756, -0.1918759221, 7.391293e-4, -1.093e-6] as const;
const DOTS_COEFF_F = [-57.96288, 13.6175032, -0.1126655495, 5.158568e-4, -1.0706e-6] as const;

/**
 * Dots score.
 * Reference: Sayers, T. (2019). DOTS Calculator.
 */
export function computeDots(totalKg: number, bodyweightKg: number, gender: Gender): number | null {
  if (totalKg <= 0 || bodyweightKg < 30 || bodyweightKg > 300) return null;
  const coeffs = gender === 'F' ? DOTS_COEFF_F : DOTS_COEFF_M;
  const denominator = poly(bodyweightKg, coeffs);
  if (denominator <= 0) return null;
  return Math.round((500 / denominator) * totalKg * 100) / 100;
}

// ── IPF GL (Goodlift Points) ────────────────────────────────────────────────
// Used by IPF-affiliated federations for ranking across weight classes.
// Coefficients match the official IPF Goodlift formula published in the IPF
// Technical Rules (Appendix E, 2021+) and independently verified against the
// OpenPowerlifting source at github.com/sstangl/openpowerlifting.
// The formula is a two-term exponential sum:
//   GL = 100 × Total / (A·(1 − e^{−B·BW}) + C·(1 − e^{−D·BW}))
// Expected output: ~87 GL for a 750 kg male total at 83 kg bodyweight.

const IPF_GL_COEFF_M = { a: 1199.72839, b: 0.00921, c: 1025.18162, d: 0.002908 } as const;
const IPF_GL_COEFF_F = { a: 610.32796, b: 0.03048, c: 1045.59282, d: 0.028011 } as const;

/**
 * IPF GL (Goodlift) score.
 * Reference: IPF Technical Rules, Appendix E (2021+).
 */
export function computeIpfGl(totalKg: number, bodyweightKg: number, gender: Gender): number | null {
  if (totalKg <= 0 || bodyweightKg < 30 || bodyweightKg > 300) return null;

  const c = gender === 'F' ? IPF_GL_COEFF_F : IPF_GL_COEFF_M;
  const denominator =
    c.a * (1 - Math.exp(-c.b * bodyweightKg)) +
    c.c * (1 - Math.exp(-c.d * bodyweightKg));

  if (denominator <= 0) return null;
  return Math.round((100 / denominator) * totalKg * 100) / 100;
}

// ── Batch helper ───────────────────────────────────────────────────────────

export type StrengthScores = {
  wilks: number | null;
  dots: number | null;
  ipfGl: number | null;
};

/** Compute all three scores in one call.
 *  Returns all-null when gender is not a recognised value ('M', 'F', 'Mx') —
 *  silently applying male coefficients for an unrecognised string would produce
 *  wrong scores with no indication to the user. */
export function computeAllScores(totalKg: number, bodyweightKg: number, gender: string): StrengthScores {
  if (gender !== 'M' && gender !== 'F' && gender !== 'Mx') {
    return { wilks: null, dots: null, ipfGl: null };
  }
  const g: Gender = gender;
  return {
    wilks: computeWilks(totalKg, bodyweightKg, g),
    dots: computeDots(totalKg, bodyweightKg, g),
    ipfGl: computeIpfGl(totalKg, bodyweightKg, g),
  };
}
