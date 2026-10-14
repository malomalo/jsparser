import LiveField from 'a'

export function colorSpectrum(value, range, saturation, lightness) {
  range = range || 360;
  saturation = saturation || 71;
  lightness = lightness || 44;
  let hue = (value * range).toString(10);
  return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
}
