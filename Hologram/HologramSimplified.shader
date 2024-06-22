Shader "HologramSimplified"
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
		_Brightness("Brightness", Range(1, 40)) = 9.15

		//primary lines
		[Toggle] _Axis("Vertical or Horizontal?", Float) = 1
		[Toggle] _LineSpace("Screenspace or object space?", Float) = 0
		_Density("Line Density", Range(0,100)) = 2.61
		_LineSpeed("Line Speed", Range(-100,100)) = 8.91
		_FlickerSpeed("Flicker Speed", Range(0,700)) = 100
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

		//rim highlights
		_RimSize("Rim Size", Range(0, 4)) = 0.6
		_RimBrightness("Rim Brightness", Range(0, 10)) = 10
	}

	CGINCLUDE //shared includes, variables, and functions
    #include "UnityCG.cginc"

	// User-specified properties
	sampler2D _MainTex;
	uniform float4 _MainTex_ST;
	sampler2D _NoiseTex;
	fixed4 _Tint;
	fixed4 _RimTint;
	float _Axis, _LineSpace, _Opacity, _CutoutOpacity;
	float _DistortAxis, _Distortion, _DistortionSpeed;
	half _Density, _Density2,  _LineSpeed,  _LineSpeed2, _FlickerSpeed, _FlickerStrength, _Brightness, _Brightness2, _RimSize, _RimBrightness;
	int _Smoothness;

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
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct appdata
			{
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 posObj : TEXCOORD1;
				float4 tex : TEXCOORD3;
				float3 normal : TEXCOORD4;
				float3 viewDir : TEXCOORD5;
			};
			v2f vert(appdata input)
			{
				v2f output;


				output.tex = input.texcoord;
				output.posObj = input.vertex;

				
				output.normal = normalize(mul(float4(input.normal, 0.0), unity_WorldToObject).xyz);
				output.viewDir = normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, input.vertex).xyz);

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

				return output;
			}

			float4 frag(v2f input) : COLOR
			{
				//uncomment this to view the distortion amount as a color output
				float distortCol = _Distortion * (tex2Dlod(_NoiseTex, float4(input.posObj.xy + _Time.y*_DistortionSpeed, 0, 0)));
				// return float4(distortCol,distortCol,distortCol,1);

				float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

				//I'm not sure why I have this line here, but it is likely some form of color correction to make things look better :/
				col.rgb = clamp(col.rgb * 0.5 + 0.5 * col.rgb * 3.2, 0.0, 1.0);
				// return float4(col.rgb, 1);

				col.rgb *= _Tint.rgb;

				//initialize PrimaryPos as 0
				//If the variable was defined inside the if statements, then the it would fall out of scope (syntax error)
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
					//when using posObj, the density has to be slightly corrected with * 50
					PrimaryPos = input.posObj[_Axis];
					_Density *= 1000;
				}

				//lines
				float lineCol = 0.9 + 0.1 * sin(_LineSpeed * _Time.y + PrimaryPos.x * _Density);
				// return float4(lineCol,lineCol,lineCol,1);

				//when using the lines, we want to use a hard threshold of 0.9, otherwise, the lines will blend into one value
				col.a = lineCol > 0.9 ? 1 : 0;
				// return float4(col.a,col.a,col.a,1);

				//if line density is 0, and speed is 0, then we must add this edge-case calculation
				//the result is that the body won't be invisible at 0 line density
				col.a = _Density == 0 ? 1 : col.a;

				// Flicker
				//this is a fullbody flicker, and does not scroll across the model
				float flicker = 0.97 + 0.03 * _FlickerStrength * sin(_FlickerSpeed * _Time.y);
				col.rgb *= flicker;
				// return (col.rgb,1);

				//secondary flicker
				//these are lines of brightness that scroll across the model
				//these are similar to the primary lines, but they do not cut out any parts of the model
				float flicker2 = sin(_LineSpeed2 * _Time.y + PrimaryPos * _Density2) * _Smoothness;
				float flicker2Adjusted = 0.9 + 0.1 * _Brightness2 * (round(flicker2) / _Smoothness);
				// float flicker2Adjusted = 0.9 + 0.1 * _Brightness2 * (Quantize(flicker2,_Smoothness));
				col.rgb *= flicker2Adjusted;
				// return float4(flicker2Adjusted,flicker2Adjusted,flicker2Adjusted,1);
				
				//rim lighting
				float3 normalDirection = normalize(input.normal);
				float3 viewDirection = normalize(input.viewDir);
				float rimcol = min(1.0, .25 / abs(pow(dot(viewDirection, normalDirection), _RimSize)));

				rimcol = rimcol > 0.5 ? 1 : 0;

				//rimcolor and the tint of rimcolor are put into the overall col
				col += 0.1 * _RimBrightness * float4(_RimTint.rgb * (rimcol), 0);

				col.rgb *= _Brightness;

				col.a = lerp(_CutoutOpacity, _Opacity, col.a);
				return col;
			}
			ENDCG
		}
	}
}