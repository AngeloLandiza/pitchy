import Foundation

/// Fundamental frequency estimation with the YIN algorithm (de Cheveigné & Kawahara, 2002).
enum YIN {
    struct Estimate: Equatable {
        var frequency: Double
        /// 0...1, higher is a cleaner periodic signal.
        var confidence: Double
    }

    static func detect(
        _ samples: UnsafeBufferPointer<Float>,
        sampleRate: Double,
        threshold: Float = 0.15,
        minFrequency: Double = 60,
        maxFrequency: Double = 1_200,
        silenceRMS: Float = 0.008
    ) -> Estimate? {
        let n = samples.count
        guard n >= 256 else { return nil }

        var energy: Float = 0
        for s in samples { energy += s * s }
        if (energy / Float(n)).squareRoot() < silenceRMS { return nil }

        let window = n / 2
        let tauMin = max(2, Int(sampleRate / maxFrequency))
        let tauMax = min(window - 1, Int(sampleRate / minFrequency))
        guard tauMax > tauMin + 2 else { return nil }

        // Difference function and its cumulative mean normalized form.
        var cmnd = [Float](repeating: 1, count: tauMax + 1)
        var runningSum: Float = 0
        for tau in 1...tauMax {
            var d: Float = 0
            for j in 0..<window {
                let delta = samples[j] - samples[j + tau]
                d += delta * delta
            }
            runningSum += d
            cmnd[tau] = runningSum > 0 ? d * Float(tau) / runningSum : 1
        }

        // First dip under the threshold, then walk down to its local minimum.
        var tau = tauMin
        var found = false
        while tau < tauMax {
            if cmnd[tau] < threshold {
                while tau + 1 < tauMax && cmnd[tau + 1] < cmnd[tau] { tau += 1 }
                found = true
                break
            }
            tau += 1
        }
        guard found else { return nil }

        // Parabolic interpolation around the minimum for sub-sample accuracy.
        var betterTau = Double(tau)
        if tau > 1 && tau < tauMax {
            let s0 = Double(cmnd[tau - 1]), s1 = Double(cmnd[tau]), s2 = Double(cmnd[tau + 1])
            let denom = 2 * (2 * s1 - s2 - s0)
            if abs(denom) > 1e-9 { betterTau += (s2 - s0) / denom }
        }

        let frequency = sampleRate / betterTau
        guard frequency >= minFrequency, frequency <= maxFrequency else { return nil }
        return Estimate(frequency: frequency, confidence: Double(1 - cmnd[tau]))
    }

    static func detect(_ samples: [Float], sampleRate: Double) -> Estimate? {
        samples.withUnsafeBufferPointer { detect($0, sampleRate: sampleRate) }
    }
}
