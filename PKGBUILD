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
sha256sums=('d7b4b9ba018a77adf118fea95b2bf2032d7cf69380193f956af5437e1115eb2b')

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
