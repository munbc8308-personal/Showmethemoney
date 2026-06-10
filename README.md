# Showmethemoney 📈

개인 퀀트 투자 자동화 앱 (iOS + macOS)

> 개인 사용 목적의 국내/해외 주식 퀀트 전략 설계, 백테스팅, 자동매매 앱

---

## 개요

직접 설계한 퀀트 전략을 앱에서 바로 백테스팅하고, 조건 충족 시 증권사 API를 통해 자동으로 주문을 실행하는 개인용 트레이딩 시스템.

- **iOS**: 포트폴리오 모니터링, 매매 신호 확인, 수동 주문
- **macOS**: 자동매매 데몬 역할 (백그라운드에서 지속 실행)

---

## 핵심 기능

### 1. 대시보드
- 국내/해외 포트폴리오 현황 (보유 종목, 평가손익, 수익률)
- 오늘의 매매 신호 요약
- 계좌 잔고 실시간 조회

### 2. 관심종목 (Watchlist)
- 종목 검색 및 등록 (국내 KOSPI/KOSDAQ, 해외 NYSE/NASDAQ)
- 실시간 시세 조회
- 차트 뷰 (캔들, 라인)

### 3. 전략 빌더 (Strategy Builder)
- 조건 기반 전략 설계 (AND/OR 조합)
- 지원 지표:
  - 이동평균선 (MA, EMA)
  - RSI (과매수/과매도)
  - MACD (시그널 교차)
  - 볼린저 밴드
  - 거래량 조건
- 매수/매도 조건 분리 설정
- 리스크 관리: 손절가, 목표가, 포지션 크기(%)

### 4. 백테스팅 (Backtesting)
- 설계한 전략을 과거 데이터로 시뮬레이션
- 결과 지표:
  - 총 수익률, 연환산 수익률
  - 샤프 비율 (Sharpe Ratio)
  - 최대 낙폭 (MDD)
  - 승률, 손익비
- 기간별 거래 내역 확인

### 5. 자동매매 (Auto Trading)
- 전략별 자동매매 ON/OFF
- 조건 충족 시 증권사 API 자동 주문
- 체결 결과 알림 (Push Notification)
- 일별 거래 한도, 종목당 최대 비중 제한

### 6. 거래 내역
- 전체 매매 기록
- 전략별 성과 분석
- 수익/손실 통계

---

## 기술 스택

| 영역 | 기술 |
|---|---|
| UI | SwiftUI |
| 로컬 저장 | SwiftData |
| 네트워킹 | URLSession + async/await |
| 차트 | Swift Charts |
| 국내 주식 시세 + 주문 | 한국투자증권 KIS Open API |
| 해외 주식 시세 + 주문 | Alpaca API |
| 과거 주가 데이터 | Yahoo Finance (비공식) |
| 플랫폼 | iOS 17+ / macOS 14+ |

---

## 데이터 모델

### `Stock` — 종목 정보
| 필드 | 타입 | 설명 |
|---|---|---|
| symbol | String | 종목 코드 (ex. 005930, AAPL) |
| name | String | 종목명 |
| market | Market | KOSPI / KOSDAQ / NYSE / NASDAQ |
| currency | String | KRW / USD |

### `Strategy` — 퀀트 전략
| 필드 | 타입 | 설명 |
|---|---|---|
| name | String | 전략 이름 |
| buyConditions | [Condition] | 매수 조건 목록 |
| sellConditions | [Condition] | 매도 조건 목록 |
| targetStocks | [Stock] | 적용 종목 |
| positionSizePct | Double | 종목당 투자 비중 (%) |
| stopLossPct | Double | 손절 비율 (%) |
| takeProfitPct | Double | 익절 비율 (%) |
| isActive | Bool | 자동매매 활성화 여부 |

### `Trade` — 거래 내역
| 필드 | 타입 | 설명 |
|---|---|---|
| stock | Stock | 종목 |
| strategy | Strategy | 실행된 전략 |
| type | TradeType | 매수 / 매도 |
| price | Double | 체결가 |
| quantity | Int | 수량 |
| executedAt | Date | 체결 시간 |
| profit | Double? | 손익 (매도 시) |

### `Account` — 계좌 정보
| 필드 | 타입 | 설명 |
|---|---|---|
| broker | Broker | KIS / Alpaca |
| balance | Double | 예수금 |
| holdings | [Holding] | 보유 종목 |

---

## 화면 구성

```
TabView
├── 홈 (Dashboard)
│   ├── 포트폴리오 요약 카드
│   ├── 오늘의 매매 신호
│   └── 최근 체결 내역
├── 관심종목 (Watchlist)
│   ├── 종목 검색
│   └── 실시간 시세 리스트
├── 전략 (Strategy)
│   ├── 전략 목록
│   ├── 전략 생성/편집
│   └── 전략별 백테스팅 결과
├── 자동매매 (Trading)
│   ├── 전략별 활성화 토글
│   ├── 실시간 신호 로그
│   └── 수동 주문
└── 설정 (Settings)
    ├── KIS API 키 설정
    ├── Alpaca API 키 설정
    └── 알림 설정
```

---

## 외부 API 연동

### 한국투자증권 KIS Open API (국내주식)
- 도메인: `https://openapi.koreainvestment.com:9443`
- 기능: 실시간 시세, 일봉/분봉 데이터, 매수/매도 주문
- 인증: OAuth2 (App Key + App Secret → Access Token)
- 참고: https://apiportal.koreainvestment.com

### Alpaca API (해외주식)
- 도메인: `https://api.alpaca.markets`
- 기능: 실시간 시세, 과거 데이터, 주문 실행 (Paper Trading 지원)
- 인증: API Key + Secret
- 참고: https://alpaca.markets/docs

### Yahoo Finance (과거 데이터 / 백테스팅용)
- 비공식 API 활용 또는 `yfinance` 형태의 URL 파싱
- 백테스팅을 위한 수년치 OHLCV 데이터 수집

---

## 자동매매 실행 방식

- **macOS**: 앱이 실행된 상태에서 타이머(60초 간격)로 전략 조건 체크 → 조건 충족 시 API 주문 실행
- **iOS**: 실시간 모니터링 및 수동 주문, Push Notification으로 신호 수신
- 주문 전 잔고/비중 검증 → 체결 결과 로컬 저장

---

## 개발 단계

- [ ] Phase 1: 기본 인프라 — 데이터 모델, API 클라이언트, 인증
- [ ] Phase 2: 시세 조회 — 국내/해외 실시간 시세, 차트
- [ ] Phase 3: 전략 빌더 — 조건 설계 UI, 지표 계산 엔진
- [ ] Phase 4: 백테스팅 — 과거 데이터 수집, 시뮬레이션 엔진
- [ ] Phase 5: 자동매매 — 주문 실행, 리스크 관리, 알림
- [ ] Phase 6: 성과 분석 — 수익률 통계, 전략 비교

---

## 주의사항

- 이 앱은 개인 사용 목적으로 제작되며 App Store 배포를 목적으로 하지 않습니다.
- 실제 자산을 다루는 앱이므로 API 키는 기기 내 Keychain에 안전하게 저장합니다.
- 자동매매 사용 시 반드시 충분한 백테스팅 후 소액으로 시작하세요.
