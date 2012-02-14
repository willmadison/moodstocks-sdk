package com.moodstocks.android;

public class Result {
	
	private int type;
	private String value;
	
	public Result(int type, String value) {
		this.type = type;
		this.value = value;
	}
	
	public String getValue() {
		return value;
	}
	
	public int getType() {
		return type;
	}
	
	@Override
	public boolean equals(Object o) {
		Result r = (Result)o;
		return ((r.type==this.type) && (r.value.equals(this.value)));
	}
	
}
