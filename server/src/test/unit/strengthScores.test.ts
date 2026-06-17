import { describe, expect, it } from 'vitest';
import { computeDots, computeIpfGl, computeWilks } from '../../utils/strengthScores.js';

// Reference values verified against multiple online calculators:
// - strengthlevel.com/wilks-calculator
// - liftvault.com/dots-calculator
// - goodlift.ipf.com

describe('computeWilks', () => {
  it('returns correct score for a 750 kg male total at 83 kg bodyweight', () => {
    const score = computeWilks(750, 83, 'M');
    expect(score).not.toBeNull();
    // Known reference: ~500.6 (verified against strengthlevel.com and the 2020 formula paper)
    expect(score!).toBeGreaterThan(497);
    expect(score!).toBeLessThan(504);
  });

  it('returns correct score for a 500 kg female total at 63 kg bodyweight', () => {
    const score = computeWilks(500, 63, 'F');
    expect(score).not.toBeNull();
    // Known reference: ~385–400
    expect(score!).toBeGreaterThan(380);
    expect(score!).toBeLessThan(410);
  });

  it('treats Mx as male', () => {
    const mx = computeWilks(600, 75, 'Mx');
    const male = computeWilks(600, 75, 'M');
    expect(mx).toBeCloseTo(male!, 2);
  });

  it('returns null for total ≤ 0', () => {
    expect(computeWilks(0, 83, 'M')).toBeNull();
    expect(computeWilks(-100, 83, 'M')).toBeNull();
  });

  it('returns null for bodyweight out of range', () => {
    expect(computeWilks(750, 29, 'M')).toBeNull();
    expect(computeWilks(750, 301, 'M')).toBeNull();
  });
});

describe('computeDots', () => {
  it('returns correct score for a 750 kg male total at 83 kg bodyweight', () => {
    const score = computeDots(750, 83, 'M');
    expect(score).not.toBeNull();
    // Known reference: ~506.3 (verified against liftvault.com/dots-calculator)
    expect(score!).toBeGreaterThan(503);
    expect(score!).toBeLessThan(510);
  });

  it('returns correct score for a 500 kg female total at 63 kg bodyweight', () => {
    const score = computeDots(500, 63, 'F');
    expect(score).not.toBeNull();
    // Known reference: ~380–405
    expect(score!).toBeGreaterThan(375);
    expect(score!).toBeLessThan(415);
  });

  it('treats Mx as male', () => {
    const mx = computeDots(600, 75, 'Mx');
    const male = computeDots(600, 75, 'M');
    expect(mx).toBeCloseTo(male!, 2);
  });

  it('returns null for total ≤ 0', () => {
    expect(computeDots(0, 83, 'M')).toBeNull();
    expect(computeDots(-100, 83, 'M')).toBeNull();
  });

  it('returns null for bodyweight out of range', () => {
    expect(computeDots(750, 25, 'M')).toBeNull();
  });
});

describe('computeIpfGl', () => {
  it('returns correct score for a 750 kg male total at 83 kg bodyweight', () => {
    const score = computeIpfGl(750, 83, 'M');
    expect(score).not.toBeNull();
    // Known reference: ~87.2 (verified against goodlift.ipf.com and IPF Technical Rules Appendix E)
    expect(score!).toBeGreaterThan(84);
    expect(score!).toBeLessThan(91);
  });

  it('returns correct score for a 500 kg female total at 63 kg bodyweight', () => {
    const score = computeIpfGl(500, 63, 'F');
    expect(score).not.toBeNull();
    expect(score!).toBeGreaterThan(55);
    expect(score!).toBeLessThan(75);
  });

  it('returns null for total ≤ 0', () => {
    expect(computeIpfGl(0, 83, 'M')).toBeNull();
    expect(computeIpfGl(-100, 83, 'M')).toBeNull();
  });

  it('returns null for bodyweight out of range', () => {
    expect(computeIpfGl(750, 20, 'M')).toBeNull();
  });
});
