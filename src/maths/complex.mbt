///|
/// A complex number. Components are immutable.
#derive(Eq, Debug)
pub(all) struct Complex {
  /// Real part of the complex value.
  re : Double
  /// Imaginary part of the complex value.
  im : Double
}

///|
/// Build a complex number from its real and imaginary parts.
/// Values are stored as supplied; this constructor does not check finiteness.
pub fn Complex::new(re : Double, im : Double) -> Complex {
  { re, im, }
}

///|
/// Build a complex number with zero imaginary part.
pub fn Complex::real(re : Double) -> Complex {
  { re, im: 0.0, }
}

///|
/// Return exp(i * angle), with the angle in radians.
pub fn Complex::phase(angle : Double) -> Complex {
  { re: @math.cos(angle), im: @math.sin(angle), }
}

///|
/// Return the complex conjugate by negating the imaginary part.
pub fn Complex::conjugate(self : Complex) -> Complex {
  { re: self.re, im: -self.im, }
}

///|
/// Return re² + im², the squared magnitude. Large values may overflow.
pub fn Complex::norm_squared(self : Complex) -> Double {
  self.re * self.re + self.im * self.im
}

///|
/// Whether both parts are finite, with neither NaN nor infinity.
pub fn Complex::is_finite(self : Complex) -> Bool {
  !self.re.is_nan() &&
  !self.re.is_inf() &&
  !self.im.is_nan() &&
  !self.im.is_inf()
}

///|
/// Multiply both parts by a real factor and return a new number.
pub fn Complex::scale(self : Complex, factor : Double) -> Complex {
  { re: self.re * factor, im: self.im * factor, }
}

///|
/// Add real and imaginary parts component by component.
pub impl Add for Complex with fn add(a, b) {
  { re: a.re + b.re, im: a.im + b.im, }
}

///|
/// Subtract real and imaginary parts component by component.
pub impl Sub for Complex with fn sub(a, b) {
  { re: a.re - b.re, im: a.im - b.im, }
}

///|
/// Multiply using complex arithmetic, without changing either input.
pub impl Mul for Complex with fn mul(a, b) {
  { re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re, }
}

///|
/// Negate both components.
pub impl Neg for Complex with fn neg(a) {
  { re: -a.re, im: -a.im, }
}

///|
/// Expose Eq operations as methods on Complex.
pub extend Complex with Eq::{equal, not_equal}

///|
/// Expose Debug operations as methods on Complex.
pub extend Complex with Debug::{to_repr}

///|
/// Expose Add operations as methods on Complex.
pub extend Complex with Add::{add}

///|
/// Expose Sub operations as methods on Complex.
pub extend Complex with Sub::{sub}

///|
/// Expose Mul operations as methods on Complex.
pub extend Complex with Mul::{mul}

///|
/// Expose Neg operations as methods on Complex.
pub extend Complex with Neg::{neg}
