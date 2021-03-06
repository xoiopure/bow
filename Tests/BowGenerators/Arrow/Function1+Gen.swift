import Bow
import SwiftCheck

// MARK: Generator for Property-based Testing

extension Function1: Arbitrary where I: CoArbitrary & Hashable, O: Arbitrary {
    public static var arbitrary: Gen<Function1<I, O>> {
        ArrowOf<I, O>.arbitrary.map { arrow in
            Function1(arrow.getArrow)
        }
    }
}

// MARK: Instance of ArbitraryK for Function1

extension Function1Partial: ArbitraryK where I: CoArbitrary & Hashable {
    public static func generate<A: Arbitrary>() -> Function1Of<I, A> {
        Function1.arbitrary.generate
    }
}
