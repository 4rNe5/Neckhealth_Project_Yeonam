import SwiftUI
import CoreMotion
import Combine

class SleepPostureManager: ObservableObject {
    private var motionManager = CMHeadphoneMotionManager()
    private var timer: Timer?
    
    @Published var currentPosture: SleepPosture = .unknown
    @Published var postureHistory: [PostureRecord] = []
    @Published var isMonitoring: Bool = false
    @Published var postureChangeCount: Int = 0
    
    struct PostureRecord: Identifiable {
        let id = UUID()
        let posture: SleepPosture
        let timestamp: Date
        let duration: TimeInterval
    }
    
    enum SleepPosture: Hashable {
        case supine
        case leftSide
        case rightSide
        case prone
        case unknown
        
        var description: String {
            switch self {
            case .supine: return "바로 누운 자세"
            case .leftSide: return "왼쪽으로 누운 자세"
            case .rightSide: return "오른쪽으로 누운 자세"
            case .prone: return "엎드린 자세"
            case .unknown: return "자세 분석 중"
            }
        }
        
        var recommendation: String {
            switch self {
                case .supine: return "편안한 자세입니다. 목 아래 얇은 베개를 사용하면 더 좋습니다."
                case .leftSide: return "양호한 자세입니다. 무릎 사이에 베개를 끼우면 더 편안할 수 있습니다."
                case .rightSide: return "양호한 자세입니다. 무릎 사이에 베개를 끼우면 더 편안할 수 있습니다."
                case .prone: return "목과 허리에 무리가 갈 수 있는 자세입니다. 자세 변경을 추천드립니다."
                case .unknown: return "자세를 분석중입니다."
            }
        }
    }
        
    
    init() {
        setupMotionManager()
    }
    
    private func setupMotionManager() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Headphone motion is not available")
            return
        }
    }
    
    func startMonitoring() {
        isMonitoring = true
        postureChangeCount = 0 // 초기화
        
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] motion, error in
            guard let self = self,
                  let motion = motion,
                  error == nil else {
                return
            }
            
            self.analyzePosture(motion: motion)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordCurrentPosture()
        }
    }
    
    private func analyzePosture(motion: CMDeviceMotion) {
        let pitch = motion.attitude.pitch
        let roll = motion.attitude.roll
        
        let newPosture: SleepPosture = {
            if abs(pitch) < 0.3 && abs(roll) < 0.3 {
                return .supine
            } else if roll > 1.0 {
                return .rightSide
            } else if roll < -1.0 {
                return .leftSide
            } else if abs(pitch) > 1.3 {
                return .prone
            }
            return .unknown
        }()
        
        if newPosture != currentPosture {
            currentPosture = newPosture
            postureChangeCount += 1
            if newPosture == .prone {
                sendPostureAlert()
            }
        }
    }
    
    private func recordCurrentPosture() {
        let record = PostureRecord(
            posture: currentPosture,
            timestamp: Date(),
            duration: 300
        )
        postureHistory.append(record)
    }
    
    private func sendPostureAlert() {
        if currentPosture == .prone {
            NotificationManager.shared.sendNotification(
                title: "수면 자세 알림",
                body: "목 건강을 위해 자세를 바로 누운 자세나 옆으로 누운 자세로 변경해주세요."
            )
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        motionManager.stopDeviceMotionUpdates()
        timer?.invalidate()
        timer = nil
    }
    
    func generateSleepReport() -> SleepReport {
        let totalDuration = postureHistory.reduce(0) { $0 + $1.duration }
        let posturePercentages = Dictionary(grouping: postureHistory, by: { $0.posture })
            .mapValues { records in
                let postureDuration = records.reduce(0) { $0 + $1.duration }
                return (postureDuration / totalDuration) * 100
            }
        
        return SleepReport(
            date: Date(),
            totalSleepDuration: totalDuration,
            posturePercentages: posturePercentages,
            recommendations: generateRecommendations(from: posturePercentages),
            sleepQuality: evaluateSleepQuality(totalDuration: totalDuration, percentages: posturePercentages)
        )
    }
    
    private func generateRecommendations(from percentages: [SleepPosture: Double]) -> [String] {
        var recommendations: [String] = []
        
        if let pronePercentage = percentages[.prone], pronePercentage > 20 {
            recommendations.append("엎드려 자는 시간이 많습니다. 목 건강을 위해 바로 눕거나 옆으로 누워주세요.")
        }
        
        if let supinePercentage = percentages[.supine], supinePercentage < 30 {
            recommendations.append("바로 누워 자는 시간을 조금 더 늘려보세요.")
        }
        
        return recommendations
    }
    
    private func evaluateSleepQuality(totalDuration: TimeInterval, percentages: [SleepPosture: Double]) -> String {
        let proneTime = (percentages[.prone] ?? 0) * totalDuration / 100
        let proneThreshold = totalDuration * 0.2 // 엎드린 자세가 20%를 초과할 경우
        
        let score: Int = {
            var points = 100
            
            // 자세 변경 횟수 점수
            switch postureChangeCount {
            case 0...10: points -= 0
            case 11...20: points -= 10
            case 21...30: points -= 20
            default: points -= 30
            }
            
            // 엎드린 시간 점수
            if proneTime > proneThreshold {
                points -= 20
            }
            
            // 수면 시간 점수
            if totalDuration < 6 * 60 * 60 { // 6시간 미만
                points -= 20
            } else if totalDuration < 8 * 60 * 60 { // 6~8시간
                points -= 10
            }
            
            return points
        }()
        
        // 점수 기반 수면 품질 평가
        switch score {
        case 80...100: return "매우 좋음"
        case 60..<80: return "좋음"
        case 40..<60: return "보통"
        case 20..<40: return "나쁨"
        default: return "매우 나쁨"
        }
    }
}

class NotificationManager {
    static let shared = NotificationManager()
    
    func sendNotification(title: String, body: String) {
        // 로컬 알림 발송 로직
    }
}
