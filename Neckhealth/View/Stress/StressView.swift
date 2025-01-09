import SwiftUI
import Charts

struct StressView: View {
    @State private var stressLevel: Int? = nil
    @State private var stressHistory: [StressData] = []
    @State private var isMeasuring = false
    @State private var isBlurred = true
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var isHeightFocused: Bool
    @FocusState private var isWeightFocused: Bool
    @StateObject private var motionManager = HeadphoneMotionManager()

    
    private let stressURL = "http://172.174.213.81:5000/predict"
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("나의\n스트레스 수치")
                    .font(.system(size: 24))
                    .bold()
                    .lineSpacing(4)
                    .padding(.leading, 10)
                Spacer()
                Button(action: measureStress) {
                    Text(isMeasuring ? "측정 중..." : (stressLevel == nil ? "측정" : "재측정"))
                        .font(.system(size: 16))
                        .fontWeight(.bold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(isMeasuring ? Color(.systemGray4) : Color("AccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(27)
                }
                .padding(.trailing, 5)
            }
            .padding()
            .padding(.top, 10)
            
            // 신체 정보 입력
            VStack(spacing: 16) {
                HStack {
                    TextField("키 (cm)", text: $height)
                        .focused($isHeightFocused)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: .infinity)
                        .onChange(of: height) { newValue in
                            saveUserData()
                        }
                    
                    TextField("몸무게 (kg)", text: $weight)
                        .focused($isWeightFocused)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: .infinity)
                        .onChange(of: weight) { newValue in
                            saveUserData()
                        }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
            
            // 메인 카드
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white)
                
                VStack(alignment: .leading, spacing: 24) {
                    if let stressLevel = stressLevel {
                        VStack(alignment: .leading, spacing: 24) {
                            // 스트레스 바
                            StressBar(stressLevel: stressLevel)
                            
                            // 현재 스트레스 수치
                            VStack(alignment: .leading, spacing: 4) {
                                Text("현재 스트레스 수치")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(stressLevel)단계")
                                    .font(.title2)
                                    .bold()
                            }
                            
                            // 차트
                            StressChart(stressHistory: stressHistory)
                                .frame(height: 200)
                                .padding(.bottom, -15)
                        }
                    } else {
                        Text("수치 측정을 해주세요.")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .blur(radius: isBlurred ? 5 : 0)
                .overlay(
                    isBlurred ? Text("수치 측정을 해주세요.")
                        .font(.headline)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.8))
                        .cornerRadius(10) : nil
                )
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
        )
        .onAppear {
            stressHistory = loadStressHistory()
            loadUserData()
        }
        .frame(height: 450)
        .frame(maxWidth: 340)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("알림"), message: Text(alertMessage), dismissButton: .default(Text("확인")))
        }
        // 화면의 다른 부분을 탭했을 때 키보드 숨기기
        .onTapGesture {
            isHeightFocused = false
            isWeightFocused = false
        }
    }
    
    // 나머지 함수들은 이전과 동일...
    private func validateInputs() -> Bool {
        guard let heightValue = Double(height), heightValue > 0,
              let weightValue = Double(weight), weightValue > 0 else {
            alertMessage = "키와 몸무게를 올바르게 입력해주세요."
            showAlert = true
            return false
        }
        return true
    }
    
    private func saveUserData() {
        UserDefaults.standard.set(height, forKey: "userHeight")
        UserDefaults.standard.set(weight, forKey: "userWeight")
    }
    
    private func loadUserData() {
        height = UserDefaults.standard.string(forKey: "userHeight") ?? ""
        weight = UserDefaults.standard.string(forKey: "userWeight") ?? ""
    }
    
    private func measureStress() {
        guard !isMeasuring else { return }
        guard validateInputs() else { return }
        
        isMeasuring = true
        isBlurred = false
        
        let roll = motionManager.roll
        let pitch = motionManager.pitch
        
        let payload: [String: Any] = [
            "rolling": [roll] ?? [0.1],
            "pitching": [pitch] ?? [0.1],
            "weight": Double(weight) ?? 0,
            "height": Double(height) ?? 0
        ]
        
        guard let url = URL(string: stressURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("JSON serialization failed: \(error)")
            isMeasuring = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { isMeasuring = false }
            
            if let error = error {
                print("Request error: \(error)")
                return
            }
            
            guard let data = data else {
                print("No response data")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let stressLevel = json["stress_level"] as? Double {
                    let roundedStress = Int(stressLevel.rounded())
                    
                    DispatchQueue.main.async {
                        self.stressLevel = roundedStress
                        let newData = StressData(date: Date(), level: Double(roundedStress))
                        self.stressHistory.append(newData)
                        saveStressHistory(self.stressHistory)
                    }
                }
            } catch {
                print("JSON parsing error: \(error)")
            }
        }.resume()
    }
    
    private func saveStressHistory(_ history: [StressData]) {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "stressHistory")
        }
    }
    
    private func loadStressHistory() -> [StressData] {
        if let data = UserDefaults.standard.data(forKey: "stressHistory"),
           let history = try? JSONDecoder().decode([StressData].self, from: data) {
            return history
        }
        return []
    }
}
