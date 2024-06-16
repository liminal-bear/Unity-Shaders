Shader "AdjustableBillboard"
{
	//billboards the model to your view, includes HueSatBrightControls

	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1
		[KeywordEnum(Opaque, Transparent, Custom)] _RenderPreset("Render Preset", Float) = 0
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4

		_Hue("Hue", Range(0,360)) = 0
		_Sat("Saturation", Range(0,10)) = 1
		_Bright("Brightness", Range(0, 100)) = 1
	}

		CGINCLUDE //shared includes, variables, and functions
		#include "UnityCG.cginc"

		// User-specified properties
	    sampler2D _MainTex;
		uniform float4 _MainTex_ST;
		uniform float _Brightness;

		float _Hue;
		float _Sat;
		float _Bright;

		float3  rgb2hsv(float3 C)
		{
			saturate(C);
			float3 HSV = { 0,1,1 };
			float _min = C.r;
			float _med = C.g;
			float _max = C.b;
			float _t = 0;
			if (_min > _med)
			{
				_t = _min;
				_min = _med;
				_med = _t;
			}
			if (_min > _max)
			{
				_t = _min;
				_min = _max;
				_max = _t;
			}
			if (_med > _max)
			{
				_t = _med;
				_med = _max;
				_max = _t;
			}

			HSV.b = _max;

			float Delta = _max - _min;
			if (_max > 0)
			{
				HSV.g = Delta / _max;
			}

			if (Delta > 0)
			{
				if (_max == C.r) HSV.r = (C.g - C.b) / Delta;
				else if (_max == C.g) HSV.r = 2.0f + (C.b - C.r) / Delta;
				else      HSV.r = 4.0f + (C.r - C.g) / Delta;
			}
			HSV.r /= 6.0f;

			return HSV;
		}
		float3 hsv2rgb(float3 C)
		{
			float c = C.z * C.y;
			float x = c * (1 - abs((C.x * 6) % 2 - 1));
			float m = C.z - c;



			float3 CC = { 0,0,0 };
			switch (floor(C.r * 6))
			{
			case 0: CC = float3(c, x, 0); break;
			case 1: CC = float3(x, c, 0); break;
			case 2: CC = float3(0, c, x); break;
			case 3: CC = float3(0, x, c); break;
			case 4: CC = float3(x, 0, c); break;
			case 5: CC = float3(c, 0, x); break;
			}
			CC.rgb += m;
			return CC;
		}

	   ENDCG
	   SubShader
	   {
		  Tags
		  {
			  "Queue" = "Transparent"
			  "RenderType" = "Transparent"
			  //"IgnoreProjector" = "True"
		      "VRCFallback" = "Toon"
		  }
		   Blend SrcAlpha OneMinusSrcAlpha // use alpha blending
		  Pass
		  {
			  //AlphaToMask On
			  Cull [_Cull]
			  ZWrite[_ZWrite]
			  Ztest[_ZTest]

			  CGPROGRAM
			  #pragma vertex vert
			  #pragma fragment frag

			  struct vertexInput
			  {
				  float4 vertex : POSITION;
				  float4 texcoord : TEXCOORD0;
				  float3 normal : NORMAL;
				  float4 tangent : TANGENT;
			  };
			  struct vertexOutput
			  {
				  float4 pos : SV_POSITION;
				  float4 tex : TEXCOORD2;
			  };
			  //CustomEditor "Scootoon_2Editor"
			  vertexOutput vert(vertexInput input)
			  {
					vertexOutput output;


					output.tex = input.texcoord;
					output.pos = UnityObjectToClipPos(input.vertex);
	

					// billboard mesh towards camera
					float3 vpos = mul((float3x3)unity_ObjectToWorld, input.vertex.xyz);
					float4 worldCoord = float4(unity_ObjectToWorld._m03, unity_ObjectToWorld._m13, unity_ObjectToWorld._m23, 1);
					float4 viewPos = mul(UNITY_MATRIX_V, worldCoord) + float4(vpos, 0);
					float4 outPos = mul(UNITY_MATRIX_P, viewPos);

					output.pos = outPos;

					return output;
			  }

			  float4 frag(vertexOutput input) : COLOR
			  {
				     half4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

					 float3 adjustedCol = col.rgb;
					 _Hue = (_Hue) / 360;
					 _Hue += 1;
					 adjustedCol = rgb2hsv(adjustedCol.rgb);
					 adjustedCol.r += _Hue;
					 adjustedCol.r %= 1;
					 adjustedCol.rgb = hsv2rgb(adjustedCol.rgb);

					 fixed lum = saturate(Luminance(adjustedCol.rgb));
					 adjustedCol.rgb = lerp(adjustedCol.rgb, fixed3(lum, lum, lum), (1 - _Sat));

					 adjustedCol.rgb *= _Bright;

					 col.rgb = adjustedCol;

					 //col.rgb = lerp(col.rgb, adjustedCol, adjustMask);

					 return float4(col.rgb * _Brightness, col.a);
			  }
			  ENDCG
		  }

	   }
}