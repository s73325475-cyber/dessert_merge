/// 보상형 광고 슬롯 / 실패 사유 (Phase 0)
enum AdPlacement {
  /// 게임 오버 계속하기
  continueGame,
  /// 보스 클리어 추가 보상
  bossExtra,
  /// 상점 코인
  coins,
}

enum AdFailReason {
  /// 시청 중 닫음 / 미시청
  dismissed,
  /// 타임아웃
  timeout,
  /// Publisher 미설정·SDK 미초기화
  notReady,
  /// 일일 시청 한도
  dailyLimit,
  /// 기타 오류
  error,
}

extension AdFailReasonMessage on AdFailReason {
  String get userMessage => switch (this) {
        AdFailReason.dismissed => '광고를 끝까지 봐야 보상이 지급됩니다.',
        AdFailReason.timeout => '광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
        AdFailReason.notReady => '광고를 준비 중이에요. 잠시 후 다시 시도해 주세요.',
        AdFailReason.dailyLimit => '오늘 이 광고 시청 한도에 도달했어요.',
        AdFailReason.error => '광고 표시에 실패했어요. 잠시 후 다시 시도해 주세요.',
      };
}

extension AdPlacementLabel on AdPlacement {
  String get debugName => switch (this) {
        AdPlacement.continueGame => 'continue',
        AdPlacement.bossExtra => 'boss',
        AdPlacement.coins => 'coins',
      };
}
