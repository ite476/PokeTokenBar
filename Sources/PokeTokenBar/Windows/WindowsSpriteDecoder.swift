#if os(Windows)
import Foundation
import WinSDK

/// PokeAPI의 PNG 바이트를 Windows가 표시할 수 있는 BGRA 픽셀로 변환한다.
///
/// Windows Swift에는 AppKit의 `NSImage`나 CoreGraphics 이미지 디코더가 없으므로
/// 운영체제가 제공하는 Windows Imaging Component(WIC)를 사용한다. WIC는 Windows
/// 10/11에 기본 포함되어 있고 PNG의 팔레트·알파·필터 종류를 모두 처리하므로,
/// 압축 포맷을 직접 추측하는 방식보다 PokeAPI sprite 호환성이 높다.
enum WindowsPNGDecoder {
    struct Image: Sendable {
        let width: Int
        let height: Int
        /// top-down 32-bit DIB에 바로 복사할 수 있는 BGRA 바이트다.
        let bgra: [UInt8]
    }

    /// WIC 디코더는 COM 객체를 사용한다. 이 함수는 백그라운드 작업 스레드에서도
    /// 호출될 수 있으므로, 이 스레드에서 COM 초기화와 해제를 한 쌍으로 수행한다.
    static func decode(_ data: Data) -> Image? {
        guard !data.isEmpty else { return nil }

        let initializeResult = CoInitializeEx(nil, DWORD(COINIT_MULTITHREADED.rawValue))
        let initializedHere = initializeResult == S_OK || initializeResult == S_FALSE
        let rpcChangedMode: HRESULT = HRESULT(bitPattern: UInt32(0x80010106))
        guard initializeResult == S_OK || initializeResult == S_FALSE || initializeResult == rpcChangedMode else {
            return nil
        }
        defer {
            if initializedHere { CoUninitialize() }
        }

        let stream: UnsafeMutablePointer<IStream>? = data.withUnsafeBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: BYTE.self).baseAddress else { return nil }
            return SHCreateMemStream(bytes, UINT(data.count))
        }
        guard let stream else { return nil }
        defer { _ = stream.pointee.lpVtbl?.pointee.Release?(stream) }

        var factoryCLSID = CLSID_WICImagingFactory
        var factoryIID = IID_IWICImagingFactory
        var rawFactory: LPVOID?
        let factoryResult = CoCreateInstance(
            &factoryCLSID,
            nil,
            DWORD(CLSCTX_INPROC_SERVER.rawValue),
            &factoryIID,
            &rawFactory)
        guard factoryResult == S_OK,
              let rawFactory,
              let factory = Optional(rawFactory.assumingMemoryBound(to: IWICImagingFactory.self)) else {
            return nil
        }
        defer { _ = factory.pointee.lpVtbl?.pointee.Release?(factory) }

        var decoder: UnsafeMutablePointer<IWICBitmapDecoder>?
        guard let createDecoder = factory.pointee.lpVtbl?.pointee.CreateDecoderFromStream else { return nil }
        let decoderResult = createDecoder(
            factory,
            stream,
            nil,
            WICDecodeMetadataCacheOnLoad,
            &decoder)
        guard decoderResult == S_OK, let decoder else { return nil }
        defer { _ = decoder.pointee.lpVtbl?.pointee.Release?(decoder) }

        var frame: UnsafeMutablePointer<IWICBitmapFrameDecode>?
        guard let getFrame = decoder.pointee.lpVtbl?.pointee.GetFrame else { return nil }
        let frameResult = getFrame(decoder, 0, &frame)
        guard frameResult == S_OK, let frame else { return nil }
        defer { _ = frame.pointee.lpVtbl?.pointee.Release?(frame) }

        var width: UINT = 0
        var height: UINT = 0
        let sizeResult = frame.pointee.lpVtbl?.pointee.GetSize?(frame, &width, &height)
        guard sizeResult == S_OK,
              width > 0,
              height > 0 else { return nil }

        var converter: UnsafeMutablePointer<IWICFormatConverter>?
        guard let createConverter = factory.pointee.lpVtbl?.pointee.CreateFormatConverter else { return nil }
        let converterResult = createConverter(factory, &converter)
        guard converterResult == S_OK, let converter else { return nil }
        defer { _ = converter.pointee.lpVtbl?.pointee.Release?(converter) }

        // IWICBitmapFrameDecode는 IWICBitmapSource를 상속한다. WinSDK Swift overlay는
        // 상속 COM 인터페이스를 자동 변환하지 않으므로, 동일한 COM 포인터를 명시한다.
        let source = UnsafeMutableRawPointer(frame).assumingMemoryBound(to: IWICBitmapSource.self)
        var pixelFormat = GUID_WICPixelFormat32bppBGRA
        let initializeConverterResult = converter.pointee.lpVtbl?.pointee.Initialize?(
            converter,
            source,
            &pixelFormat,
            WICBitmapDitherTypeNone,
            nil,
            0,
            WICBitmapPaletteTypeCustom)
        guard initializeConverterResult == S_OK else { return nil }

        let widthInt = Int(width)
        let heightInt = Int(height)
        let stride = widthInt.multipliedReportingOverflow(by: 4)
        let byteCount = stride.partialValue.multipliedReportingOverflow(by: heightInt)
        guard !stride.overflow, !byteCount.overflow, byteCount.partialValue > 0 else { return nil }

        var bgra = [UInt8](repeating: 0, count: byteCount.partialValue)
        guard let copyPixels = converter.pointee.lpVtbl?.pointee.CopyPixels else { return nil }
        let pixelsResult = bgra.withUnsafeMutableBufferPointer { buffer in
            copyPixels(
                converter,
                nil,
                UINT(stride.partialValue),
                UINT(byteCount.partialValue),
                buffer.baseAddress)
        }
        guard pixelsResult == S_OK else { return nil }
        return Image(width: widthInt, height: heightInt, bgra: bgra)
    }
}

/// 디코드된 BGRA 이미지에서 투명도를 유지하는 Win32 icon을 만든다.
enum WindowsSpriteIconFactory {
    static func make(data: Data?) -> HICON? {
        guard let data, let image = WindowsPNGDecoder.decode(data) else { return nil }
        var info = BITMAPINFO()
        info.bmiHeader.biSize = UINT(MemoryLayout<BITMAPINFOHEADER>.size)
        info.bmiHeader.biWidth = Int32(image.width)
        info.bmiHeader.biHeight = -Int32(image.height)
        info.bmiHeader.biPlanes = 1
        info.bmiHeader.biBitCount = 32
        info.bmiHeader.biCompression = DWORD(BI_RGB)

        var pixelPointer: UnsafeMutableRawPointer?
        guard let colorBitmap = CreateDIBSection(nil, &info, UINT(DIB_RGB_COLORS), &pixelPointer, nil, 0),
              let pixelPointer else { return nil }
        image.bgra.withUnsafeBytes { source in
            guard let baseAddress = source.baseAddress else { return }
            pixelPointer.copyMemory(from: baseAddress, byteCount: source.count)
        }

        guard let maskBitmap = CreateBitmap(Int32(image.width), Int32(image.height), 1, 1, nil) else {
            DeleteObject(colorBitmap)
            return nil
        }
        var iconInfo = ICONINFO()
        iconInfo.fIcon = true
        iconInfo.hbmColor = colorBitmap
        iconInfo.hbmMask = maskBitmap
        let icon = CreateIconIndirect(&iconInfo)
        DeleteObject(colorBitmap)
        DeleteObject(maskBitmap)
        return icon
    }
}
#endif
