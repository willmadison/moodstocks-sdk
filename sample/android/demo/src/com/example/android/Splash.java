package com.example.android;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.TextView;

public class Splash extends RelativeLayout {
	
	public static final String TAG = "Splash";
	public boolean progressing = false;

	public Splash(Context context, AttributeSet attrs) {
		super(context, attrs);
	}
	
	public void show(boolean b) {
		int v = b ? View.VISIBLE : View.INVISIBLE;
		((Splash) findViewById(R.id.splash)).setVisibility(v);
		((ProgressBar) findViewById(R.id.infinite)).setVisibility(v);
		v = b ? View.INVISIBLE : View.VISIBLE;
		((ProgressBar) findViewById(R.id.progress)).setVisibility(v);
		if (b) ((TextView) findViewById(R.id.splash_text)).setText(R.string.initializing);
	}
	
	public void update(int total, int current) {
		if (!progressing) {
			ProgressBar bar = (ProgressBar) findViewById(R.id.progress);
			progressing = true;
			((ProgressBar) findViewById(R.id.infinite)).setVisibility(View.INVISIBLE);
			bar.setVisibility(View.VISIBLE);
			bar.setMax(total);
		}
		((ProgressBar) findViewById(R.id.progress)).setProgress(current);
		((TextView) findViewById(R.id.splash_text)).setText(current+" / "+total);
	}


}
