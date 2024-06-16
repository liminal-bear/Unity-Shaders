Shader "screenGrabPass"
{
	Properties
	{
		[KeywordEnum(Default, Overlay)] _RenderMode("Render Mode", Float) = 0
		_MainTex("UI Texture", 2D) = "black" { }
		_RenderRange("RenderRange", Range(0, 99)) = 1

		[KeywordEnum(Off, Front, Back)] _CullingMode("Cull Mode", Float) = 0

		_Brightness("Brightness", Range(0, 5)) = 1
		_CAdjust("Color Adjust", Range(0, 1)) = 0.2
	}
	SubShader
		{
		Tags {
			"RenderType" = "TransparentCutout"
			"Queue" = "Transparent+2000"}
		AlphaToMask On
			ZWrite off
			LOD 100
			Cull[_CullingMode]
			GrabPass { "_GrabTexture" }
		Pass
			{
			blend srcalpha oneminussrcalpha
			CGPROGRAM
				#pragma vertex vert
#pragma fragment frag
#pragma multi_compile_fog
#pragma target 4.0
#pragma shader_feature PP_ON
#pragma shader_feature LR_ON

# include "UnityCG.cginc"
			sampler2D _GrabTexture;


			float PureGray(float3 color)
			{
				return (color.r + color.g + color.b) / 3;
			}
			float3 rgb2hsv(float3 C)
			{
				saturate(C);
				float3 HSV = { 0, 1, 1 };
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
					else HSV.r = 4.0f + (C.r - C.g) / Delta;
				}
				HSV.r /= 6.0f;

				return HSV;
			}
			float3 hsv2rgb(float3 C)
			{
				float c = C.z * C.y;
				float x = c * (1 - abs((C.x * 6) % 2 - 1));
				float m = C.z - c;



				float3 CC = { 0, 0, 0 };
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

				struct appdata
{
	float4 vertex : POSITION;
					float2 uv : TEXCOORD0;
				};

struct v2f
{
	float4 uv : TEXCOORD0;
					UNITY_FOG_COORDS(1)
					float4 vertex : SV_POSITION;
					float4 distance : TEXCOORD2;
				};

sampler2D _MainTex;
float4 _MainTex_ST;
float _Brightness;
float _Outline;
float _OutlineWidth;
float _RenderMode;
float _RenderRange;
float distance;
float _UDL;
float _BBC;
float _Hue;
float _Sat;
float _CAdjust;

v2f vert(appdata v)
{
	v2f o;
	o.vertex = UnityObjectToClipPos(v.vertex);

	o.distance.x = o.vertex.w;
	o.uv = o.vertex;


	if (_RenderMode > 0)
	{
		o.uv = float4(TRANSFORM_TEX(v.uv, _MainTex), 1, 1);
		o.vertex.xy = o.uv;
		o.vertex.xy -= 0.5;
		o.vertex.xy *= 2;
		o.vertex.y = -o.vertex.y;
		o.vertex.zw = 1;
	}


	UNITY_TRANSFER_FOG(o, o.vertex);
	return o;
}


fixed4 frag(v2f i) : SV_Target
{

	if (_RenderMode > 0)
	{
	}
	else
	{

		i.uv.xy /= i.uv.w;
		i.uv.x = (i.uv.x + 1) / 2;
		i.uv.y = 1 - (i.uv.y + 1) / 2;
	}

#if UNITY_SINGLE_PASS_STEREO
					 i.uv.x /= 2;

					if (unity_StereoEyeIndex > 0)
					{
						i.uv.x += 0.5;
					}
#endif


	fixed4 col_base = tex2D(_GrabTexture, i.uv.xy);
	fixed gray = PureGray(col_base.rgb);
	fixed4 colorAdjusted = float4(col_base.rgb / (gray - _CAdjust), 1);

	float4 col = colorAdjusted;

	col.rgb *= _Brightness;
	return col;
}
ENDCG
			}
		}
}
//ahzkwid
