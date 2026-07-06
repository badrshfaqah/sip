import SwiftUI

/// هوية الشركة البصرية — عدّل هذه القيم لتطابق ألوان شعار الشركة.
enum Brand {
    /// اللون الأساسي للهوية
    static let primary = Color(red: 0.05, green: 0.35, blue: 0.65)
    /// اللون الثانوي
    static let secondary = Color(red: 0.95, green: 0.65, blue: 0.15)
    /// لون النجاح (متصل)
    static let success = Color.green
    /// لون الخطأ
    static let danger = Color.red
    /// لون التحذير (جاري التسجيل)
    static let warning = Color.orange

    /// اسم صورة الشعار داخل Assets — استبدل الملف بشعار الشركة
    static let logoAssetName = "CompanyLogo"

    /// اسم الشركة الظاهر في الواجهة
    static let companyName = "Badr"
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
            ZStack {
                RoundedRectangle(cornerRadius: size / 4.5, style: .continuous)
                    .fill(LinearGradient(colors: [Brand.primary, Brand.primary.opacity(0.7)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "phone.fill")
                    .font(.system(size: size / 2.2, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }
}
