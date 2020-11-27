// MIT License
//
// Copyright © 2020 Darren Mo.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Cocoa

extension NSCoding {
   public static func make<OriginalClass: NSObject & NSCoding>(
      bySerializingAndDeserializing originalObject: OriginalClass
   ) throws -> Self {
      let serializedData = try NSKeyedArchiver.archivedData(withRootObject: originalObject,
                                                            requiringSecureCoding: false)

      let unarchiver = try NSKeyedUnarchiver(forReadingFrom: serializedData)
      defer {
         unarchiver.finishDecoding()
      }

      unarchiver.requiresSecureCoding = false

      let archivedClassName =
         originalObject.classForKeyedArchiver.map { String(cString: class_getName($0)) } ??
         originalObject.className
      // Hack: This might replace a descendent object’s class whereas we only want to replace
      // the root object’s class. However, this is the only way to replace the class.
      unarchiver.setClass(Self.self, forClassName: archivedClassName)

      guard let deserializedObject = try unarchiver.decodeTopLevelObject(forKey: NSKeyedArchiveRootObjectKey) else {
         throw unarchiver.error!
      }

      return deserializedObject as! Self
   }
}
