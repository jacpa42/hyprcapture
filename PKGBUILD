# Maintainer: Jacob Enthoven <jacpa42@proton.me>

pkgname=hyprcapture
pkgver=0.0.1
pkgrel=1
pkgdesc="Application usage tracker"
arch=('x86_64' 'aarch64' 'i686')
url="https://github.com/jacpa42/$pkgname"
license=('MIT')
makedepends=('git' 'zig')
source=("https://github.com/jacpa42/${pkgname}/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('46ed0a9c7e04b8be44a562527fd19984cad2780f25dab033669104b9bf208567')

build() {
    cd "$srcdir/$pkgname-${pkgver}"
    zig build -Doptimize=ReleaseFast
}

package() {
    cd "$srcdir/$pkgname-${pkgver}"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
    install -Dm755 "zig-out/bin/$pkgname" "$pkgdir/usr/bin/$pkgname"
}
