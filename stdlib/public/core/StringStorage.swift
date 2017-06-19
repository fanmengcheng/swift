//===--- StringStorage.swift ----------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import SwiftShims
extension _SwiftUTF16StringHeader : _BoundedBufferHeader {
  public init(count: Int, capacity: Int) {
    self.count = numericCast(count)
    self.capacity = numericCast(capacity)
    self.flags = 0
  }
}
extension _SwiftLatin1StringHeader : _BoundedBufferHeader {
  public init(count: Int, capacity: Int) {
    self.count = numericCast(count)
    self.capacity = numericCast(capacity)
    self.flags = 0
  }
}

/// Common base class of our string storage classes
extension String {
  internal class _StorageBase<
    Header: _BoundedBufferHeader,
    Element: UnsignedInteger
  > :
  // Dynamically provides inheritance from NSString
  _SwiftNativeNSString {
    @nonobjc
    final internal var _header: Header

    // satisfies the compiler's demand for a designated initializer
    @nonobjc
    internal init(_doNotCallMe: ()) { fatalError("do not call me") }
    
    @objc
    final public func length() -> Int {
      return numericCast(_header.count)
    }

    @objc(copyWithZone:)
    final public func copy(with: _SwiftNSZone?) -> AnyObject {
      return self
    }
    
    @objc
    final public func characterAtIndex(_ index: Int) -> UInt16 {
      defer { _fixLifetime(self) }
      return numericCast(_baseAddress[index])
    }
    
    @nonobjc
    var _baseAddress: UnsafeMutablePointer<Element> {
      // WORKAROUND: rdar://31047127 prevents us from implementing _baseAddress as
      // final here.
      fatalError("Override me!")
    }
  }  
}

extension String._StorageBase : _FactoryInitializable {
  @nonobjc
  @inline(__always)
  public convenience init(uninitializedWithMinimumCapacity n: Int) {
    self.init(
      Builtin.allocWithTailElems_1(
        type(of: self), n._builtinWordValue, Element.self))
  }
}

//===--- UTF16 String Storage ---------------------------------------------===//
extension String {
  @_versioned
  internal final class _UTF16Storage
    : String._StorageBase<_SwiftUTF16StringHeader, UTF16.CodeUnit>,
      _NSStringCore {
    // WORKAROUND: helping type inference along will be unnecessary someday
    public typealias Element = UInt16
    public typealias Iterator = IndexingIterator<String._UTF16Storage>
    
    //===--- _NSStringCore conformance --------------------------------------===//
    // There doesn't seem to be a way to write these in an extension

    /// Returns a pointer to contiguously-stored UTF-16 code units
    /// comprising the whole string, or NULL if such storage isn't
    /// available.
    ///
    /// WARNING: don't use this method from Swift code; ARC may end the
    /// lifetime of self before you get a chance to use the result.
    @objc
    public func _fastCharacterContents() -> UnsafePointer<UInt16>? {
      return UnsafePointer(_baseAddress)
    }

    /// Returns a pointer to contiguously-stored code units in the
    /// system encoding comprising the whole string, or NULL if such
    /// storage isn't available.
    ///
    // WARNING: don't use this method from Swift code; ARC may end the lifetime of
    // self before you get a chance to use the result.
    // WARNING: Before you implement this as anything other than “return nil,”
    // see https://github.com/apple/swift/pull/3151#issuecomment-285583557
    @objc
    public func _fastCStringContents(
      _ nullTerminationRequired: Int8
    ) -> UnsafePointer<CChar>? {
      return nil
    }

    // WORKAROUND: rdar://31047127 prevents us from hoisting this into
    // _StringStorageBase
    @nonobjc
    public override var _baseAddress: UnsafeMutablePointer<UTF16.CodeUnit> {
      return UnsafeMutablePointer(
        Builtin.projectTailElems(self, Element.self))
    }
  }
}


extension String._UTF16Storage : _BoundedBufferReference {
  /// Returns empty singleton that is used for every single empty String.
  /// The contents of the storage should never be mutated.
  @nonobjc
  public static func _emptyInstance() -> String._UTF16Storage {
    return Builtin.bridgeFromRawPointer(
      Builtin.addressof(&_swiftEmptyStringStorage))
  }
  
  @nonobjc
  public static var extraCapacity: Int { return 1 }
}

extension String._UTF16Storage /*: UnicodeStorage*/ {
  public typealias Encoding = Unicode.UTF16

  @nonobjc
  public var isKnownASCII: Bool {
    get { return _header.flags & 1<<0 as UInt16 != 0 }
    set {
      if newValue { _header.flags |= 1<<0 as UInt16 }
      else { _header.flags &= ~(1<<0) }
    }
  }

  @nonobjc
  public var isKnownLatin1: Bool {
    get { return _header.flags & 1<<1 as UInt16 != 0 }
    set {
      if newValue { _header.flags |= 1<<1 as UInt16 }
      else { _header.flags &= ~(1<<1) as UInt16 }
    }
  }
  
  @nonobjc
  public var isKnownValidEncoding: Bool {
    get { return _header.flags & 1<<2 as UInt16 != 0 }
    set {
      if newValue { _header.flags |= 1<<2 as UInt16 }
      else { _header.flags &= ~(1<<2) as UInt16 }
    }
  }
  
  @nonobjc
  public var isKnownFCCNormalized: Bool {
    get { return _header.flags & 1<<3 as UInt16 != 0 }
    set {
      if newValue { _header.flags |= 1<<3 as UInt16 }
      else { _header.flags &= ~(1<<3) as UInt16 }
    }
  }
  
  @nonobjc
  public var isKnownNFCNormalized: Bool {
    get { return _header.flags & 1<<4 as UInt16 != 0 }
    set {
      if newValue { _header.flags |= 1<<4 as UInt16 }
      else { _header.flags &= ~(1<<4) as UInt16 }
    }
  }
  
  @nonobjc
  public var isKnownNFDNormalized: Bool {
    get { return _header.flags & 1<<5 as UInt16 != 0 }
    set {
      if newValue { _header.flags |= 1<<5 as UInt16 }
      else { _header.flags &= ~(1<<5) as UInt16 }
    }
  }
  
  @nonobjc
  @_versioned
  internal func _setMaxStored(_ maxCodeUnit: UInt16) {
    switch maxCodeUnit {
    case 0..<0x80: self.isKnownASCII = true; fallthrough
    case 0..<0x100: self.isKnownLatin1 = true; fallthrough
    case 0..<0x300: self.isKnownFCCNormalized = true; fallthrough
    case 0..<0xD800: self.isKnownValidEncoding = true
    default: break
    }
  }
  
  @nonobjc
  @inline(__always)
  public convenience init<Source : Collection>(
    _ source: Source,
    maxElement: UInt16? = nil
  )
  where Source.Iterator.Element == UInt16 {
    self.init(count: numericCast(source.count))
    withUnsafeMutableBufferPointer {
      source._copyCompleteContents(initializing: $0)
    }
    _setMaxStored(maxElement ?? source.max() ?? 0)
  }

  @nonobjc
  @inline(__always)
  public convenience init(
    count: Int,
    minimumCapacity: Int = 0
  ) {
    self.init(minimumCapacity: Swift.max(count, minimumCapacity)) {
      _SwiftUTF16StringHeader(
        count: UInt32(count), capacity: UInt32($0), flags: 0)
    }
  }
}

//===--- Latin-1 String Storage -------------------------------------------===//
extension String {
  @_versioned
  internal final class _Latin1Storage
  : String._StorageBase<_SwiftLatin1StringHeader, UInt8>,
    _NSStringCore // Ensures that we implement essential NSString methods.  
  {
    // WORKAROUND: helping type inference along will be unnecessary someday
    public typealias Element = UInt8
    public typealias Iterator = IndexingIterator<String._Latin1Storage>
    
    //===--- _NSStringCore conformance --------------------------------------===//
    // There doesn't seem to be a way to write these in an extension

    /// Returns a pointer to contiguously-stored UTF-16 code units
    /// comprising the whole string, or NULL if such storage isn't
    /// available.
    ///
    /// WARNING: don't use this method from Swift code; ARC may end the
    /// lifetime of self before you get a chance to use the result.
    @objc
    public func _fastCharacterContents() -> UnsafePointer<UInt16>? {
      return nil
    }

    /// Returns a pointer to contiguously-stored code units in the
    /// system encoding comprising the whole string, or NULL if such
    /// storage isn't available.
    ///
    // WARNING: don't use this method from Swift code; ARC may end the lifetime of
    // self before you get a chance to use the result.
    // WARNING: Before you implement this as anything other than “return nil,”
    // see https://github.com/apple/swift/pull/3151#issuecomment-285583557
    @objc
    public func _fastCStringContents(
      _ nullTerminationRequired: Int8
    ) -> UnsafePointer<CChar>? {
      return nil
    }
    
    // WORKAROUND: rdar://31047127 prevents us from hoisting this into
    // _StringStorageBase
    @nonobjc
    public override var _baseAddress: UnsafeMutablePointer<UInt8> {
      return UnsafeMutablePointer(
        Builtin.projectTailElems(self, Element.self))
    }
  }
}

extension String._Latin1Storage : _BoundedBufferReference {
  @nonobjc
  public static var extraCapacity: Int { return 1 }
  
  @nonobjc
  public static func _emptyInstance() -> String._Latin1Storage {
    return String._Latin1Storage(uninitializedWithMinimumCapacity: 0)
  }
  
  @nonobjc
  @inline(__always)
  public convenience init(
    count: Int,
    minimumCapacity: Int = 0
  ) {
    self.init(minimumCapacity: Swift.max(count, minimumCapacity)) {
      _SwiftLatin1StringHeader(
        count: UInt32(count), capacity: UInt32($0), flags: 0)
    }
  }
}

extension String._Latin1Storage {
  public var isKnownNFDNormalized: Bool { return true }
  public var isKnownNFCNormalized: Bool { return true }

  @nonobjc
  public var isKnownASCII: Bool {
    get { return _header.flags & (1 as UInt8)<<0 != 0 }
    set {
      if newValue { _header.flags |= (1 as UInt8)<<0 }
      else { _header.flags &= ~((1 as UInt8)<<0) }
    }
  }

  @nonobjc
  public convenience init<Source : Collection>(
    _ source: Source,
    isKnownASCII: Bool = false
  )
  where Source.Iterator.Element == UInt8 {
    self.init(count: numericCast(source.count))
    withUnsafeMutableBufferPointer {
      source._copyCompleteContents(initializing: $0)
    }
    self.isKnownASCII = isKnownASCII || (source.max() ?? 0) < 0x80
  }
}

//===--- Multi-Format String Storage --------------------------------------===//

@inline(__always)
public func _mkLatin1<C: Collection>(_ x: C, isKnownASCII: Bool = false) -> AnyObject
where C.Element == UInt8
{
  return String._Latin1Storage(x, isKnownASCII: isKnownASCII)
}

@inline(__always)
public func _mkUTF16<C: Collection>(_ x: C, maxElement: UInt16? = nil) -> AnyObject
where C.Element == UInt16
{
  return String._UTF16Storage(x, maxElement: maxElement)
}

extension String {
  internal enum _Content {
    internal struct _ShortLatin1 {
      var _codeUnits: (UInt64, UInt32, UInt16)
      var _count: UInt8
    }
  case shortLatin1(_ShortLatin1)
    
    internal struct _ShortUTF16 {
      var _codeUnits: (UInt64, UInt32, UInt16)
      var _count: UInt8
    }
  case shortUTF16(_ShortUTF16)

    internal struct _UnownedLatin1 {
      var _start: UnsafePointer<UInt8>, count: UInt32, isASCII: Bool
    }
  case unownedLatin1(_UnownedLatin1)
    
    internal struct _UnownedUTF16 {
      var _start: UnsafePointer<UInt8>, count: UInt32, isASCII: Bool
    }
  case unownedUTF16(_UnownedUTF16)
    
  case latin1(_Latin1Storage)
  case utf16(_UTF16Storage)
  case nsString(_NSStringCore)
  }
}

