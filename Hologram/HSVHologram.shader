Shader "HologramHSV"
{
	//hologram shader
	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
	    _NoiseTex("Model Noise Texture", 2D) = "black" {}
		_Tint("Tint Color", Color) = (0,.61,.55)
		_RimTint("RimTint Color", Color) = (0,.61,.55)
		_Opacity("Opacity", Range(0,1)) = 1
		_CutoutOpacity("CutoutOpacity", Range(0,1)) = 0
		_Hue("Hue", Range(0, 360)) = 0
		_Sat("Saturation", Range(0, 10)) = 1
		_Brightness("Brightness", Range(1, 40)) = 9.15

		//primary lines
		[Toggle] _Axis("Vertical or Horizontal?", Float) = 1
		[Toggle] _LineSpace("Screenspace or object space?", Float) = 0
		_Density("Line Density", Range(0,0.5)) = 2.61
		// _Thickness("Line Thickness", Range(.5, .63)) = .56
		_Thickness("Line Thickness", Range(0, 2)) = .56
		_LineSpeed("Line Speed", Range(-100,100)) = 8.91
		_Flicker("Flickering", Range(0,1000)) = 100
		_FlickerStrength("Flicker Strength", Range(0,10)) = 2.7

		//primary lines
		[Toggle] _DistortAxis("Distortion Vertical or Horizontal?", Float) = 1
		_Distortion("model Distortion", Range(0,1)) = 0.02
		_DistortionSpeed("_Distortion Speed", Range(-10,10)) = 0.3

		//secondary lines
		_Density2("Secondary flicker Density", Range(0,1000)) = 7
		_Smoothness("Secondary flicker smoothness ", Range(1,100)) = 2
		_LineSpeed2("Secondary flicker Speed", Range(-10,10)) = 3.7
		_Brightness2("secondary flicker brightness", Range(1, 10)) = 4.55

		_RimSize("Rim Size", Range(0, 4)) = 0.6
		_RimBrightness("Rim Brightness", Range(0, 10)) = 10
	}

	CGINCLUDE //shared includes, variables, and functions
    #include "UnityCG.cginc"

	//uniform float4 _LightColor0;
	// color of light source (from "Lighting.cginc")

	// User-specified properties
	sampler2D _MainTex;
	uniform float4 _MainTex_ST;
	sampler2D _NoiseTex;
	fixed4 _Tint;
	float _Hue;
	float _Sat;
	fixed4 _RimTint;
	float _Axis, _LineSpace, _Opacity, _CutoutOpacity;
	float _DistortAxis, _Distortion, _DistortionSpeed;
	half _Density, _Density2,  _LineSpeed,  _LineSpeed2, _Flicker, _FlickerStrength, _Brightness, _Brightness2, _RimSize, _RimBrightness;
	float _Thickness;
	int _Smoothness;

	//psuedo random number generator
	float random(float2 seed)
	{
	   return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
	}
	
	float saw(float x)
	{
		return 1 * (x - floor(0.5 + x));
		// return 2 * (x - lerp(x,int(x), pow(frac(x),.5)));
	}

	float Quantize(float num, float quantize)
	{
	   return round(num * quantize) / quantize;
	}

	half3 AdjustContrast(half3 color, half contrast) {
		return saturate(lerp(half3(0.5, 0.5, 0.5), color, contrast));
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


	ENDCG
	SubShader
	{
		Tags
		{
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
		    "VRCFallback" = "Toon"
		}
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend SrcAlpha One
		Pass
		{
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
			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 posWorld : TEXCOORD0;
				float4 posObj : TEXCOORD1;
				float4 screenPos : TEXCOORD2;
				// position of the vertex (and fragment) in world space 
				float4 tex : TEXCOORD3;
				float3 normal : TEXCOORD4;
				float3 viewDir : TEXCOORD5;
				//float3 tangentWorld : TEXCOORD4;
				//float3 normalWorld : TEXCOORD5;
				//float3 binormalWorld : TEXCOORD6;
			};
			v2f vert(vertexInput input)
			{
				v2f output;

				output.normal = normalize(mul(float4(input.normal, 0.0), unity_WorldToObject).xyz);
				output.viewDir = normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, input.vertex).xyz);

				//output.tangentWorld = normalize(
				//	mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
				//output.normalWorld = normalize(
				//	mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
				//output.binormalWorld = normalize(
				//	cross(output.normalWorld, output.tangentWorld)
				//	* input.tangent.w); // tangent.w is specific to Unity

				//output.posWorld = mul(modelMatrix, input.vertex);
				output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
				output.tex = input.texcoord;
				//output.pos = UnityObjectToClipPos(input.vertex);
				output.posObj = input.vertex;


				//distortion amount, uses modifies the local coordinate, by an amount specified by noise and _Distortion
				//because we are in the vertex shader, we must use the tex2Dlod to access the texture
				//float4 adjustedDimension = 0.01 * sin(_LineSpeed * _Time.y + output.posWorld.x * _Density);
				float adjustedDimension = _Distortion * (tex2Dlod(_NoiseTex, float4(output.posObj.xy + _Time.y*_DistortionSpeed, 0, 0)));

				if(_DistortAxis == 1)
				{
					input.vertex.x += adjustedDimension;
				}
				else
				{
					input.vertex.y += adjustedDimension;
				}

				output.pos = UnityObjectToClipPos(input.vertex);
				output.screenPos = ComputeScreenPos(output.pos);
				//output.pos = UnityObjectToClipPos(newVertexPos);
				//float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
				//half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
				//half3 shlight = ShadeSH9(float4(worldN, 1.0));

				return output;
			}

			float4 frag(v2f input) : COLOR
			{
					float distortCol = _Distortion * (tex2Dlod(_NoiseTex, float4(input.posObj.xy + _Time.y*_DistortionSpeed, 0, 0)));
					// return float4(distortCol,distortCol,distortCol,1);

				    float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
					col.rgb = clamp(col.rgb * 0.5 + 0.5 * col.rgb * 3.2, 0.0, 1.0);
					col.rgb *= _Tint.rgb;

					float PrimaryPos = 0;

					//if statement for determining scan line space
					//screenspace is pretty good, but since it's dependent on screenspace, then it might rotate wrongly when your head is 90degrees
					//object space is dependent on the model, and is in line with the model, without respect to head rotation
					//however, object space is taking cross sections of the model, and might appear warped as it scrolls down flat areas
					if (_LineSpace == 0)
					{
						PrimaryPos = input.pos[_Axis];
						_Density2 /= 1000;
					}
					else
					{
						PrimaryPos = input.posObj[_Axis];
						_Density *= 1000;
					}

					 


					//lines
					//col.a = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((input.pos.x + adjustment)* _Density))) > 0.9 ? 1 : 0;

					//col.a = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((input.pos.x + adjustment)* _Density))) > 0.9 ? 1 : 0;
					// col.a = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((PrimaryPos ) * _Density))) > 0.9 ? 1 : 0;
					float lineTest = 1 + 1 * saw(_LineSpeed * _Time.y + ((PrimaryPos) * _Density));


					// return float4(lineTest,lineTest,lineTest,1);



					col.a = col.a * lineTest > _Thickness ? 1 : 0;
					// return float4(col.a,col.a,col.a,1);

					col.a = _Density == 0 ? 1 : col.a;

					//col.a = 0.5 + sin(_LineSpeed * _Time.y + ((input.pos.x + adjustment)* _Density));
					//col.a = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((input.pos.z * 99) * _Density))) > 0.9 ? 1 : 0;
					//col.rgb = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((input.posObj.y + random(input.posObj.x) > 0.99 ? 0.1 : -.1) * _Density))) > 0.9 ? 1 : 0;
					//col.rgb = round(input.posObj.y * 100) / 100;
					//col.rgb = (input.posObj.y > .2 ? 1 : 0) + round(random(input.posObj.x) * _Quantize) / _Quantize;
					//float adjustedPos = input.posObj.y + round(input.posObj.z * _Quantize) / _Quantize;// +round(random(input.posObj.z) * _Quantize) / _Quantize;
					//float adjustedPos = input.posObj.y + (random(round(input.posObj.z * _Quantize) / _Quantize)) * _Distortion;// +round(random(input.posObj.z) * _Quantize) / _Quantize;
					//float adjustedPos = input.posObj.y + (sin(round(input.posObj.z * _Quantize) / _Quantize) * _Distortion);// +round(random(input.posObj.z) * _Quantize) / _Quantize;
					//col.rgb = (adjustedPos > .2 ? 1 : 0);
					//col.a = 0.9 + 0.1 * round(sin(_LineSpeed * _Time.y + input.posWorld.y * _Density) * _Quantize) / _Quantize;

					//col.rgb = round(sin(input.posWorld.y * _Density) * _Quantize) / _Quantize;
					//col.rgb = input.pos.z * 99;
					//col.a = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + (random(_Time.w)) * _Density)) > 0.9 ? 1 : 0;
					//col.a = random(input.posObj.y * 9 % 2) > 0.5 ? 1 : 0;
					 
					// Flicker
					col.rgb *= 0.97 + 0.03 * _FlickerStrength * sin(_Flicker * _Time.y);

					//secondary flicker
					col.rgb *= 0.9 + 0.1 * _Brightness2 * round(sin(_LineSpeed2 * _Time.y + PrimaryPos * _Density2) * _Smoothness) / _Smoothness;
					
		

					//rim lighting
					float3 normalDirection = normalize(input.normal);
					float3 viewDirection = normalize(input.viewDir);
					float newOpacity = min(1.0, .25 / abs(pow(dot(viewDirection, normalDirection), _RimSize)));
					newOpacity = newOpacity > 0.5 ? 1 : 0;
					//newOpacity = Quantize(newOpacity, 10);

					col += 0.1 * _RimBrightness * float4(_RimTint.rgb * (newOpacity), 0);

					//col.rgb *= _Brightness;

					float3 adjustedCol = col.rgb;
					_Hue = (_Hue) / 360;
					_Hue += 1;
					adjustedCol = rgb2hsv(adjustedCol.rgb);
					adjustedCol.r += _Hue;
					adjustedCol.r %= 1;
					adjustedCol.rgb = hsv2rgb(adjustedCol.rgb);

					fixed lum = saturate(Luminance(adjustedCol.rgb));
					adjustedCol.rgb = lerp(adjustedCol.rgb, fixed3(lum, lum, lum), (1 - _Sat));

					adjustedCol.rgb *= _Brightness;

					//col.rgb = lerp(col.rgb, adjustedCol, adjustMask);
					col.rgb = adjustedCol;


					col.a = lerp(_CutoutOpacity, _Opacity, col.a);
					clip(col.a-0.01);
					//col.a = 1;
					return col;
			}
			ENDCG
		}

	}
}
