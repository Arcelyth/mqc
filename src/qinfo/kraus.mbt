///|
priv struct KrausMap(@circuit.Channel)

///|
/// Return the channel's linear action on a row-major square matrix block.
/// The block may be an off-diagonal block of a larger system.
///
/// $$
/// \mathcal E(B)=\sum_k K_k B K_k^\dagger,\qquad B\in\mathbb C^{d\times d}.
/// $$
pub fn kraus_map(channel : @circuit.Channel) -> &@circuit.LinearKernel {
  KrausMap(channel)
}

///|
impl @circuit.LinearKernel for KrausMap with fn size(self) {
  let d = self.0.size()
  d * d
}

///|
/// Sum K ρ K† over the channel's Kraus operators. Every term reads the
/// same input block. Store ρ K† by column so K can act on each column
/// using the channel's existing matrix-vector kernel.
impl @circuit.LinearKernel for KrausMap with fn apply(self, args) {
  let d = self.0.size()
  let right_re = Array::make(d * d, 0.0)
  let right_im = Array::make(d * d, 0.0)
  let conjugated_im = Array::make(d, 0.0)
  let re = Array::make(d, 0.0)
  let im = Array::make(d, 0.0)
  for i in 0..<(d * d) {
    args.output_re[i] = 0.0
    args.output_im[i] = 0.0
  }
  for kernel in self.0.kernels() {
    for row in 0..<d {
      let offset = row * d
      for col in 0..<d {
        conjugated_im[col] = -args.input_im[offset + col]
      }
      kernel.apply({
        input_re: args.input_re[offset:offset + d],
        input_im: conjugated_im[:],
        output_re: re.mut_view(),
        output_im: im.mut_view(),
      })
      for col in 0..<d {
        right_re[col * d + row] = re[col]
        right_im[col * d + row] = -im[col]
      }
    }
    for col in 0..<d {
      let offset = col * d
      kernel.apply({
        input_re: right_re[offset:offset + d],
        input_im: right_im[offset:offset + d],
        output_re: re.mut_view(),
        output_im: im.mut_view(),
      })
      for row in 0..<d {
        args.output_re[row * d + col] += re[row]
        args.output_im[row * d + col] += im[row]
      }
    }
  }
}
