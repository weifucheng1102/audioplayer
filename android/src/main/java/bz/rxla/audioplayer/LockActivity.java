/*
 * @Description: 锁屏插件修改
 * @Author: dmlzj
 * @Github: https://github.com/dmlzj
 * @Email: 284832506@qq.com
 * @Date: 2019-08-29 10:15:19
 * @LastEditors: dmlzj
 * @LastEditTime: 2019-09-04 10:32:06
 * @如果有bug，那肯定不是我的锅，嘤嘤嘤
 */
package bz.rxla.audioplayer;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.widget.ImageView;
import android.widget.TextView;

import com.bumptech.glide.Glide;
import com.bumptech.glide.load.resource.bitmap.CircleCrop;
import com.bumptech.glide.request.RequestOptions;

import bz.rxla.audioplayer.receiver.ScreenListener;
import bz.rxla.audioplayer.trans.GlideCircleWithBorder;

public class LockActivity extends Activity {

    String name;
    String img;
    String url;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.getWindow().addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED);
        setContentView(R.layout.lockactivity);
        initControl();
    }

    private void initControl() {

        name = getIntent().getStringExtra("name");
        img = getIntent().getStringExtra("img");
        url = getIntent().getStringExtra("url");

        findViewById(R.id.back).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                finish();
            }
        });

        TextView tv_name = (TextView) findViewById(R.id.tv_name);
        ImageView iv_img = (ImageView) findViewById(R.id.iv_img);
        final ImageView iv_play = (ImageView) findViewById(R.id.iv_play);

        if (name!=null && name.length()>0){
            tv_name.setText(name);
        }

        if (img!=null && img.length()>0){
            Glide.with(this)
                    .load(img)
                    .apply(RequestOptions.bitmapTransform(new GlideCircleWithBorder(6, Color.parseColor("#66000000"))))

//                .apply(RequestOptions.bitmapTransform(new CircleCrop()))
                    .into(iv_img);
        }

        iv_play.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if(AudioplayerPlugin.mediaPlayer!=null){

                    if (AudioplayerPlugin.mediaPlayer.isPlaying()){
                        AudioplayerPlugin.pause();
                        iv_play.setImageDrawable(getResources().getDrawable(R.drawable.ic_play_btn_play) );
                    } else {

//                        AudioplayerPlugin.mediaPlayer.start();
                        AudioplayerPlugin.play(url);
                        iv_play.setImageDrawable(getResources().getDrawable(R.drawable.ic_play_btn_pause) );
                    }

                }
            }
        });

        registLisener(this);
    }

    ScreenListener l ;
    private void registLisener(final Context context) {
        l = new ScreenListener(context);
        l.begin(new ScreenListener.ScreenStateListener() {
            @Override
            public void onUserPresent() {
                Log.e("onUserPresent", "onUserPresent");
                // finish();
            }

            @Override
            public void onScreenOn() {
            }

            @Override
            public void onScreenOff() {

            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        l.unregisterListener();
    }

    @Override
    public void onBackPressed() {
        // do nothing
    }
}
