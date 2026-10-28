//
//  VisualComponents.swift
//  MVVM_Local
//
//  短视频页面用到的基础视觉组件：渐变、占位色、远程图片。
//

import SnapKit
import UIKit

enum PlaceholderPalette {
    private static let gradients: [(UIColor, UIColor)] = [
        (UIColor(red: 0.23, green: 0.08, blue: 0.30, alpha: 1), UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)),
        (UIColor(red: 0.28, green: 0.05, blue: 0.16, alpha: 1), UIColor(red: 0.06, green: 0.04, blue: 0.06, alpha: 1)),
        (UIColor(red: 0.04, green: 0.20, blue: 0.27, alpha: 1), UIColor(red: 0.04, green: 0.07, blue: 0.09, alpha: 1)),
        (UIColor(red: 0.26, green: 0.13, blue: 0.05, alpha: 1), UIColor(red: 0.06, green: 0.05, blue: 0.04, alpha: 1)),
        (UIColor(red: 0.11, green: 0.20, blue: 0.07, alpha: 1), UIColor(red: 0.04, green: 0.06, blue: 0.04, alpha: 1))
    ]

    static func colors(for seed: String) -> [UIColor] {
        let pair = gradients[index(for: seed) % gradients.count]
        return [pair.0, pair.1]
    }

    static func color(for seed: String) -> UIColor {
        colors(for: seed).first ?? UIColor(white: 0.15, alpha: 1)
    }

    static func initial(for name: String) -> String {
        let clean = name.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespaces)
        return clean.first.map(String.init) ?? "V"
    }

    private static func index(for seed: String) -> Int {
        var hash = 0
        for byte in seed.utf8 {
            hash = (hash &* 31 &+ Int(byte)) % 100_000
        }
        return hash
    }
}

final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
    }

    convenience init() {
        self.init(frame: .zero)
    }

    func configure(colors: [UIColor],
                   locations: [NSNumber]? = nil,
                   startPoint: CGPoint = CGPoint(x: 0.5, y: 0),
                   endPoint: CGPoint = CGPoint(x: 0.5, y: 1)) {
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.locations = locations
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
    }
}

final class CoverPlaceholderView: UIView {
    private lazy var gradient: GradientView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.18)
        label.font = .systemFont(ofSize: 88, weight: .black)
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        addSubview(gradient)
        addSubview(label)

        gradient.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    convenience init() {
        self.init(frame: .zero)
    }

    func configure(seed: String, name: String) {
        gradient.configure(colors: PlaceholderPalette.colors(for: seed))
        label.text = PlaceholderPalette.initial(for: name)
    }
}

/// 带取消能力的远程图片视图，避免 Cell 复用时旧图覆盖新图。
final class RemoteImageView: UIImageView {
    private var task: URLSessionDataTask?
    private var currentURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    convenience init() {
        self.init(frame: .zero)
    }

    deinit {
        task?.cancel()
    }

    func setImage(url: URL?) {
        task?.cancel()
        task = nil
        currentURL = url
        image = nil

        guard let url else { return }

        task = ImageLoader.shared.load(url) { [weak self] image in
            guard let self, self.currentURL == url else { return }
            self.image = image
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        currentURL = nil
        image = nil
    }
}

final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
        cache.countLimit = 120
    }

    @discardableResult
    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        let key = url.absoluteString as NSString
        if let image = cache.object(forKey: key) {
            DispatchQueue.main.async { completion(image) }
            return nil
        }

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            if let error = error as? URLError, error.code == .cancelled { return }

            guard let data,
                  let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self?.cache.setObject(image, forKey: key)
            DispatchQueue.main.async { completion(image) }
        }
        task.resume()
        return task
    }
}
