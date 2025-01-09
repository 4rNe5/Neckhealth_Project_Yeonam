import SwiftUI

struct TurtleNeckView: View {
    @StateObject private var motionManager = HeadphoneMotionManager()
    
    var statusType: StatusType {
        let adjustedPitch = motionManager.pitch - motionManager.baselinePitch
        if adjustedPitch > -0.1 {
            return .safe
        } else if adjustedPitch >= -0.18 {
            return .caution
        } else {
            return .turtle
        }
    }
    
    var statusMessage: String {
        let status = motionManager.neckStatus
        switch status {
        case "안정적인 자세": return "안정적인 자세"
        case "자세를 조정하세요": return "자세를 조정하세요"
        case "거북목 주의!": return "거북목 주의!"
        default: return "자세를 확인하세요"
        }
    }
    
    var statusSubMessage: String {
        let status = motionManager.neckStatus
        switch status {
        case "안정적인 자세": return "목건강을 위해 자세를 유지해주세요"
        case "자세를 조정하세요": return "목건강을 위해 자세를 변경해주세요"
        case "거북목 주의!": return "목건강을 위해 자세를 즉시 변경해주세요"
        default: return "목건강을 위해 자세를 확인해주세요"
        }
    }
    
    var body: some View {
        VStack(spacing: 40) {
            // 수평계 뷰
            ZStack {
                ForEach(1...3, id: \.self) { index in
                    Circle()
                        .stroke(Color.black.opacity(0.5), lineWidth: 2)
                        .frame(width: CGFloat(80 * index), height: CGFloat(80 * index))
                }
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 30, height: 30)
                    .offset(
                        x: CGFloat(min(max(motionManager.roll * 200, -100), 100)),
                        y: CGFloat(min(max((motionManager.pitch - motionManager.baselinePitch) * -200, -100), 100))
                    )
                    .animation(.easeOut(duration: 0.2), value: motionManager.pitch)
            }
            .frame(width: 240, height: 240)
            
            // 상태 카드
            StatusCard(
                type: statusType,
                message: statusMessage,
                subMessage: statusSubMessage
            )
            .padding(.horizontal)
            
            // 영점 조절 버튼
            Button(action: {
                motionManager.calibrate()
            }) {
                Text("영점 조정하기")
                    .font(.system(size: 17))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("AccentColor"))
                    .cornerRadius(20)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            motionManager.startMonitoring()
        }
        .onDisappear {
            motionManager.stopMonitoring()
        }
    }
}
