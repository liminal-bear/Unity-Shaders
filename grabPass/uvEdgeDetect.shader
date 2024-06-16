Shader "UVEdgeDetect"
{

	//Runs edge detection on a grabpass (scenery behind it)
	//another earlier pass exists, but is commented out
	//it does a regular unlit texture pass, but if edge detection is ran on it, with the UV map texture, it will create an outline effect

	Properties
	{
		_MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1

		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
		
		_TintColor("Tint Color", Color) = (1,1,1,1)

		_AdjustMask("Color Adjustment mask", 2D) = "white" {}
		_Hue("Hue", Range(0,360)) = 0
		_Sat("Saturation", Range(0,10)) = 1
		_Bright("Brightness", Range(0, 100)) = 1

		_BBC("BlendBlackColor", Range(0,0.9)) = 0.2
		_Outline("OutlineBrightness", Range(0,8)) = 2
		_OutlineWidth("OutlineWidth", Range(0,1)) = 0.5
		_Contrast("contrast", Range(0,10))=1
	}

		CGINCLUDE //shared includes, variables, and functions
#include "UnityCG.cginc"

// User-specified properties
sampler2D _MainTex;
		uniform float4 _MainTex_ST;
		uniform float4 _TintColor;
		uniform float _Brightness;
		float _Outline;
		float _OutlineWidth;
		float _UDL;
		float _BBC;
		float _Contrast;

		float _Hue;
		float _Sat;
		float _Bright;

		float PureGray(float3 color)
		{
			return (color.r + color.g + color.b) / 3;
		}

		half3 AdjustContrast(half3 color, half contrast) {
			return saturate(lerp(half3(0.5, 0.5, 0.5), color, contrast));
		}

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
				"IgnoreProjector" = "True"
				"VRCFallback" = "Toon"
			}

			// Pass
			// {
			// 	CGPROGRAM
			// 	#pragma vertex vert
			// 	#pragma fragment frag

			// 	struct vertexInput
			// 	{
			// 		float4 vertex : POSITION;
			// 		float4 texcoord : TEXCOORD0;
			// 		float3 normal : NORMAL;
			// 		float4 tangent : TANGENT;
			// 	};

			// 	struct vertexOutput
			// 	{
			// 		float4 pos : SV_POSITION;
			// 		//float4 posWorld : TEXCOORD0;
			// 		//float4 posObj : TEXCOORD1;
			// 		// position of the vertex (and fragment) in world space 
			// 		float4 tex : TEXCOORD2;
			// 		//float3 tangentWorld : TEXCOORD3;
			// 		//float3 normalWorld : TEXCOORD4;
			// 		//float3 binormalWorld : TEXCOORD5;
			// 	};

			// 	vertexOutput vert(vertexInput input)
			// 	{
			// 		vertexOutput output;

			// 		output.tex = input.texcoord;
			// 		output.pos = UnityObjectToClipPos(input.vertex);
			// 		return output;
			// 	}

			// 	float4 frag(vertexOutput input) : COLOR
			// 	{
			// 			half4 color = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

			// 			return color;
			// 	}
			// 	ENDCG
			// }


			GrabPass {"_SCTGrabTexture" }

			Pass
			{
				Cull[_Cull]
				ZWrite[_ZWrite]
				Ztest[_ZTest]

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag

					sampler2D _SCTGrabTexture;

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
					//float4 posWorld : TEXCOORD0;
					//float4 posObj : TEXCOORD1;
					// position of the vertex (and fragment) in world space 
					float4 tex : TEXCOORD2;
					float4 grabPos : TEXCOORD0;
					//float3 tangentWorld : TEXCOORD3;
					//float3 normalWorld : TEXCOORD4;
					//float3 binormalWorld : TEXCOORD5;
				};
				//CustomEditor "Scootoon_2Editor"
				vertexOutput vert(vertexInput input)
				{
						vertexOutput output;

						//float4x4 modelMatrix = unity_ObjectToWorld;
						//float4x4 modelMatrixInverse = unity_WorldToObject;

						//output.tangentWorld = normalize(
						//	mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
						//output.normalWorld = normalize(
						//	mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
						//output.binormalWorld = normalize(
						//	cross(output.normalWorld, output.tangentWorld)
						//	* input.tangent.w); // tangent.w is specific to Unity

						////output.posWorld = mul(modelMatrix, input.vertex);
						//output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
						//output.tex = input.texcoord;
						output.pos = UnityObjectToClipPos(input.vertex);
						output.grabPos = ComputeGrabScreenPos(output.pos);

						//output.posObj = input.vertex;
						////float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
						////half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
						//half3 worldN = UnityObjectToWorldNormal(input.normal);
						//half3 shlight = ShadeSH9(float4(worldN, 1.0));

						return output;
				}

				float4 frag(vertexOutput input) : COLOR
				{
					fixed4 col_base = tex2Dproj(_SCTGrabTexture, input.grabPos.xyzw);
					fixed gray = PureGray(col_base.rgb);
					fixed4 colorBrightened = float4(col_base.rgb / (gray + 0.02), 1);

					//fixed4 col2  = abs(col_base-tex2D( _GrabTexture, float2(i.uv.x+0.002*_OutlineWidth,i.uv.y)));  
					//fixed4 col3 = abs(col_base-tex2D( _GrabTexture, float2(i.uv.x,i.uv.y+0.002*_OutlineWidth)));  
					//fixed4 col = col_base;				
					fixed4 col2 = abs(col_base - tex2Dproj(_SCTGrabTexture, float4(input.grabPos.x + 0.002 * _OutlineWidth, input.grabPos.y, input.grabPos.z, input.grabPos.w)));
					fixed4 col3 = abs(col_base - tex2Dproj(_SCTGrabTexture, float4(input.grabPos.x, input.grabPos.y + 0.002 * _OutlineWidth, input.grabPos.z, input.grabPos.w)));

					fixed4 gray2 = PureGray(col2.rgb);
					col2 = col2 / gray + 0.02;
					gray2 = PureGray(col3.rgb);
					col3 = col3 / gray + 0.02;

					fixed4 col = colorBrightened;
					col = (col2 + col3) / 2;

					col.g = max(col.r, max(col.g, col.b));
					col.r = 0;
					col.b = 0;
					col = col * 32 * _Outline * _Brightness;
					//col.g += max(col_base.r,max(colorBrightened.g, colorBrightened.b)) * _Brightness;
					col.g += max(colorBrightened.r, max(colorBrightened.g, colorBrightened.b)) * _Brightness;
					col.g = min(col.g, 1);

					col.g *= 1 - _BBC;

					col.rgb = AdjustContrast(col.rgb, _Contrast);

					col.rgb = lerp(0,_TintColor, col.g);

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

					col.rgb = adjustedCol.rgb;

					//return col2 * _Brightness;
					return col;
				}
				ENDCG
			}

		}
}