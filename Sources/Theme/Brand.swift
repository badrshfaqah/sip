import SwiftUI

/// هوية شركة "المطورين Developers" — رمادي داكن + أحمر من الشعار.
enum Brand {
    /// اللون الأساسي: الرمادي الداكن (لون الشعار)
    static let primary = Color(red: 0.23, green: 0.23, blue: 0.24)      // #3A3A3D
    /// اللون الثانوي: الأحمر (سهم الشعار والنص العربي)
    static let secondary = Color(red: 0.93, green: 0.26, blue: 0.20)    // #ED4233
    /// لون النجاح (متصل)
    static let success = Color.green
    /// لون الخطأ
    static let danger = Color.red
    /// لون التحذير (جاري التسجيل)
    static let warning = Color.orange

    /// اسم صورة الشعار داخل Assets — ضع شعار الشركة (PNG) في CompanyLogo.imageset
    static let logoAssetName = "CompanyLogo"

    /// اسم الشركة الظاهر في الواجهة
    static let companyName = "المطورين Developers"
}

extension View {
    /// تدرّج الهوية للأزرار الرئيسية
    func brandButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(
                LinearGradient(colors: [Brand.primary, Brand.primary.opacity(0.8)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// شعار الشركة مع بديل تلقائي إن لم تُضف الصورة بعد
struct CompanyLogoView: View {
    var size: CGFloat = 80

    var body: some View {
        if let image = NSImage(named: Brand.logoAssetName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // بديل مؤقت بألوان الشعار (رمادي داكن + أحمر) حتى تُضاف صورة الشعار
            ZStack {
                RoundedRectangle(cornerRadius: size / 4.5, style: .continuous)
                    .fill(LinearGradient(colors: [Brand.primary, Brand.primary.opacity(0.82)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "phone.fill")
                    .font(.system(size: size / 2.2, weight: .semibold))
                    .foregroundColor(Brand.secondary)
            }
            .frame(width: size, height: size)
        }
    }
}
