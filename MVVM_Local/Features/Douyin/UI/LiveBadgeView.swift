//
//  LiveBadgeView.swift
//  MVVM_Local
//
//  「直播中」标签：红底胶囊 + 呼吸圆点，列表和信息流共用。
//  动画只改圆点透明度，不触发布局，列表滚动时也不掉帧。
//

import SnapKit
import UIKit

final class LiveBadgeView: UIView {
    private lazy var dotView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 3
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "直播中"
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        return label
    }()

    private lazy var stack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [dotView, titleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        return stack
    }()

    private let pulseKey = "liveBadgePulse"

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor(red: 0.98, green: 0.12, blue: 0.30, alpha: 1)
        layer.cornerRadius = 9
        clipsToBounds = true
        isUserInteractionEnabled = false

        addSubview(stack)

        dotView.snp.makeConstraints { make in
            make.width.height.equalTo(6)
        }

        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(7)
            make.trailing.equalToSuperview().offset(-8)
            make.top.equalToSuperview().offset(3)
            make.bottom.equalToSuperview().offset(-3)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    convenience init() {
        self.init(frame: .zero)
    }

    /// 开始呼吸动画；`viewDidDisappear` / 复用前记得 stop，避免在屏幕外空转。
    func startAnimating() {
        guard dotView.layer.animation(forKey: pulseKey) == nil else { return }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.25
        animation.duration = 0.7
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dotView.layer.add(animation, forKey: pulseKey)
    }

    func stopAnimating() {
        dotView.layer.removeAnimation(forKey: pulseKey)
    }
}
