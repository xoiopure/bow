//
//  IO.swift
//  CategoryCore
//
//  Created by Tomás Ruiz López on 29/11/17.
//  Copyright © 2017 Tomás Ruiz López. All rights reserved.
//

import Foundation

public class IOF {}

public class IO<A> : HK<IOF, A> {
    
    public static func ev(_ fa : HK<IOF, A>) -> IO<A> {
        return fa.ev()
    }
    
    public static func pure(_ a : A) -> IO<A> {
        return Pure(a)
    }
    
    public static func suspend(_ f : @escaping () -> IO<A>) -> IO<A> {
        return Pure<Unit>(()).flatMap(f)
    }
    
    public static func raiseError(_ error : Error) -> IO<A> {
        return RaiseError(error)
    }
    
    public static func tailRecM<B>(_ a : A, _ f : @escaping (A) -> HK<IOF, Either<A, B>>) -> IO<B> {
        return IO<Either<A, B>>.ev(f(a)).flatMap { either in
            either.fold({ a in tailRecM(a, f) },
                        { b in IO<B>.pure(b) })
        }
    }
    
    public func unsafePerformIO() throws -> A {
        fatalError("Implement in subclasses")
    }
    
    public func attempt() -> IO<Either<Error, A>>{
        fatalError("Implement in subclasses")
    }
    
    public func unsafeRunAsync(_ callback : Callback<A>) {
        do {
            callback(Either.right(try unsafePerformIO()))
        } catch {
            callback(Either.left(error))
        }
    }
    
    public func map<B>(_ f : @escaping (A) -> B) -> IO<B> {
        return FMap(f, self)
    }
    
    public func ap<B>(_ ff : IO<(A) -> B>) -> IO<B> {
        return ff.flatMap(self.map)
    }
    
    public func flatMap<B>(_ f : @escaping (A) -> IO<B>) -> IO<B> {
        return Join(self.map(f))
    }
    
    public func handleErrorWith(_ f : @escaping (Error) -> HK<IOF, A>) -> IO<A> {
        return attempt().flatMap{ either in either.fold({ e in f(e).ev() }, IO<A>.pure) }
    }
}

fileprivate class Pure<A> : IO<A> {
    let a : A
    
    init(_ a : A) {
        self.a = a
    }
    
    override func attempt() -> IO<Either<Error, A>> {
        return Pure<Either<Error, A>>(Either<Error, A>.right(a))
    }
    
    override func unsafePerformIO() throws -> A {
        return a
    }
}

fileprivate class RaiseError<A> : IO<A> {
    let error : Error
    
    init(_ error : Error) {
        self.error = error
    }
    
    override func attempt() -> IO<Either<Error, A>> {
        return Pure<Either<Error, A>>(Either<Error, A>.left(error))
    }
    
    override func unsafePerformIO() throws -> A {
        throw error
    }
}

fileprivate class FMap<A, B> : IO<B> {
    let f : (A) -> B
    let action : IO<A>
    
    init(_ f : @escaping (A) -> B, _ action : IO<A>) {
        self.f = f
        self.action = action
    }
    
    override func attempt() -> IO<Either<Error, B>> {
        do {
            return try Pure<Either<Error, B>>(Either<Error, B>.right(self.unsafePerformIO()))
        } catch {
            return Pure<Either<Error, B>>(Either<Error, B>.left(error))
        }
    }
    
    override func unsafePerformIO() throws -> B {
        return f(try action.unsafePerformIO())
    }
}

fileprivate class Join<A> : IO<A> {
    let io : IO<IO<A>>
    
    init(_ io : IO<IO<A>>) {
        self.io = io
    }
    
    override func attempt() -> IO<Either<Error, A>> {
        do {
            return try Pure<Either<Error, A>>(Either<Error, A>.right(self.unsafePerformIO()))
        } catch {
            return Pure<Either<Error, A>>(Either<Error, A>.left(error))
        }
    }
    
    override func unsafePerformIO() throws -> A {
        return try io.unsafePerformIO().unsafePerformIO()
    }
}

public extension HK where F == IOF {
    public func ev() -> IO<A> {
        return self as! IO<A>
    }
}

public extension IO {
    public static func functor() -> IOFunctor {
        return IOFunctor()
    }
    
    public static func applicative() -> IOApplicative {
        return IOApplicative()
    }
    
    public static func monad() -> IOMonad {
        return IOMonad()
    }
    
    /*public static func asyncContext() -> IOAsyncContext {
        return IOAsyncContext()
    }*/
    
    public static func monadError() -> IOMonadError {
        return IOMonadError()
    }
    
    public static func semigroup<SemiG>(_ semigroup : SemiG) -> IOSemigroup<A, SemiG> {
        return IOSemigroup<A, SemiG>(semigroup)
    }
    
    public static func monoid<Mono>(_ monoid : Mono) -> IOMonoid<A, Mono> {
        return IOMonoid<A, Mono>(monoid)
    }
    
    public static func eq<EqA, EqError>(_ eq : EqA, _ eqError : EqError) -> IOEq<A, EqA, EqError> {
        return IOEq<A, EqA, EqError>(eq, eqError)
    }
}

public class IOFunctor : Functor {
    public typealias F = IOF
    
    public func map<A, B>(_ fa: HK<IOF, A>, _ f: @escaping (A) -> B) -> HK<IOF, B> {
        return IO.ev(fa).map(f)
    }
}

public class IOApplicative : IOFunctor, Applicative {
    public func pure<A>(_ a: A) -> HK<IOF, A> {
        return IO.pure(a)
    }
    
    public func ap<A, B>(_ fa: HK<IOF, A>, _ ff: HK<IOF, (A) -> B>) -> HK<IOF, B> {
        return fa.ev().ap(ff.ev())
    }
}

public class IOMonad : IOApplicative, Monad {
    public func flatMap<A, B>(_ fa: HK<IOF, A>, _ f: @escaping (A) -> HK<IOF, B>) -> HK<IOF, B> {
        return fa.ev().flatMap({ a in f(a).ev() })
    }
    
    public func tailRecM<A, B>(_ a: A, _ f: @escaping (A) -> HK<IOF, Either<A, B>>) -> HK<IOF, B> {
        return IO.tailRecM(a, f)
    }
}

/*public class IOAsyncContext : AsyncContext {
    public typealias F = IOF
    
    public func runAsync<A>(_ fa: @escaping ((Either<Error, A>) -> Unit) throws -> Unit) -> HK<IOF, A> {
        return IO.runAsync(fa)
    }
}*/

public class IOMonadError : IOMonad, MonadError {
    public typealias E = Error
    
    public func raiseError<A>(_ e: Error) -> HK<IOF, A> {
        return IO.raiseError(e)
    }
    
    public func handleErrorWith<A>(_ fa: HK<IOF, A>, _ f: @escaping (Error) -> HK<IOF, A>) -> HK<IOF, A> {
        return fa.ev().handleErrorWith(f)
    }
}

public class IOSemigroup<B, SemiG> : Semigroup where SemiG : Semigroup, SemiG.A == B {
    public typealias A = HK<IOF, B>
    
    private let semigroup : SemiG
    
    public init(_ semigroup : SemiG) {
        self.semigroup = semigroup
    }
    
    public func combine(_ a: HK<IOF, B>, _ b: HK<IOF, B>) -> HK<IOF, B> {
        return a.ev().flatMap { aa in b.ev().map { bb in self.semigroup.combine(aa, bb) } }
    }
}

public class IOMonoid<B, Mono> : IOSemigroup<B, Mono>, Monoid where Mono : Monoid, Mono.A == B {
    private let monoid : Mono
    
    override public init(_ monoid : Mono) {
        self.monoid = monoid
        super.init(monoid)
    }
    
    public var empty: HK<IOF, B> {
        return IO.pure(monoid.empty)
    }
}

public class IOEq<B, EqB, EqError> : Eq where EqB : Eq, EqB.A == B, EqError : Eq, EqError.A == Error {
    public typealias A = HK<IOF, B>
    
    private let eq : EqB
    private let eqError : EqError
    
    public init(_ eq : EqB, _ eqError : EqError) {
        self.eq = eq
        self.eqError = eqError
    }
    
    public func eqv(_ a: HK<IOF, B>, _ b: HK<IOF, B>) -> Bool {
        var aValue, bValue : B?
        var aError, bError : Error?
        
        do {
            aValue = try a.ev().unsafePerformIO()
        } catch {
            aError = error
        }
        
        do {
            bValue = try b.ev().unsafePerformIO()
        } catch {
            bError = error
        }
        
        if let aV = aValue, let bV = bValue {
            return eq.eqv(aV, bV)
        } else if let aE = aError, let bE = bError {
            return eqError.eqv(aE, bE)
        } else {
            return false
        }
    }
}
