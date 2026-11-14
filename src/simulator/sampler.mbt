///|
pub(open) trait Sampler {
  fn run(Self, params : ParamBinding?, repititon : UInt32) -> SamplerResult
}
