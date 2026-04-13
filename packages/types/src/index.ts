export enum ResolverKind {
  Direction = "direction",
  Threshold = "threshold",
  RangeClose = "range_close",
}

export enum EpochStatus {
  Open = "open",
  Locked = "locked",
  Resolved = "resolved",
  Cancelled = "cancelled",
}

export enum PositionSide {
  For = "for",
  Against = "against",
}

export type Outcome = boolean;
