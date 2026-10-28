//
//  LiveEnterButton.swift
//  MVVM_Local
//
//  直播封面上的「点击进入直播间」胶囊：左侧是三根上下跳动的声浪条（播放器动画）。
//  整块只负责展示，点击交给 LiveCardCell 的手势，所以 isUserInteractionEnabled = false。
//  动画每根条错开 beginTime，看起来像音量在跳动；离开屏幕 / 复用时 stop，避免空转。
//

import SnapKit
import UIKit

// MARK: - 声浪条

final class LiveWaveView: UIView {
    private let animationKey = "liveWaveBounce"

    /// 三根条的基础高度（bar 宽度固定 2pt，间距 2pt）。
    private let barHeights: [CGFloat] = [7, 12, 9]

    private lazy var bars: [UIView] = barHeights.map { _ in
        let bar = UIView()
        bar.backgroundColor = .white
        bar.layer.cornerRadius = 1
        // 以底边为缩放中心，缩放时像音量条一样上下伸缩。
        bar.layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        return bar
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        bars.forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: barWidth * CGFloat(bars.count) + spacing * CGFloat(bars.count - 1),
               height: barHeights.max() ?? 12)
    }

    private var barWidth: CGFloat { 2 }
    private var spacing: CGFloat { 2 }

    override func layoutSubviews() {
        super.layoutSubviews()

        // anchorPoint 改过之后仍然可以直接用 frame：UIKit 会按 position/bounds 换算。
        var x = (bounds.width - intrinsicContentSize.width) / 2
        for (index, bar) in bars.enumerated() {
            let height = barHeights[index]
            bar.frame = CGRect(x: x, y: bounds.height - height, width: barWidth, height: height)
            x += barWidth + spacing
        }
    }

    func startAnimating() {
        guard bars.first?.layer.animation(forKey: animationKey) == nil else { return }

        let now = CACurrentMediaTime()
        for (index, bar) in bars.enumerated() {
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 0.3
            animation.toValue = 1.0
            animation.duration = 0.42
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.beginTime = now + Double(index) * 0.13
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.layer.add(animation, forKey: animationKey)
        }
    }

    func stopAnimating() {
        bars.forEach { $0.layer.removeAnimation(forKey: animationKey) }
    }
}

// MARK: - 进入直播间胶囊

final class LiveEnterButton: UIView {
    private lazy var waveView = LiveWaveView()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "点击进入直播间"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        return label
    }()

    private lazy var stack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [waveView, titleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 参考抖音：半透明玻璃胶囊 + 白色声浪条。
        backgroundColor = UIColor.white.withAlphaComponent(0.26)
        layer.cornerRadius = 17
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        clipsToBounds = true
        isUserInteractionEnabled = false

        addSubview(stack)

        waveView.snp.makeConstraints { make in
            make.width.equalTo(10)
            make.height.equalTo(12)
        }

        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func startAnimating() {
        waveView.startAnimating()
    }

    func stopAnimating() {
        waveView.stopAnimating()
    }
}
