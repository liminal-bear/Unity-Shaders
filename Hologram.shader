Shader "Hologram"
{
	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
	    _NoiseTex("Model Noise Texture", 2D) = "black" {}
		_Tint("Tint Color", Color) = (0,156,134)
		_Opacity("Opacity", Range(0,1)) = 1

		//primary lines
		[Toggle] _Axis("Vertical or Horizontal?", Float) = 0
		[Toggle] _LineSpace("Screenspace or object space?", Float) = 0
		_Density("Line Density", Range(0,10)) = 2.61
		_Distortion("model Distortion", Range(0,1)) = 0.02
		_LineSpeed("Line Speed", Range(-10,10)) = 8.91
		_Flicker("Flickering", Range(100,1000)) = 100
		_FlickerStrength("Flicker Strength", Range(1,10)) = 2.7

		//secondary lines
		_Brightness("Brightness", Range(1, 10)) = 9.15
		_Density2("Secondary flicker Density", Range(0,100)) = 7
		_Quantize("Secondary flicker smoothness ", Range(1,100)) = 2
		_LineSpeed2("Secondary flicker Speed", Range(-10,10)) = 3.7
		_Brightness2("secondary flicker brightness", Range(1, 10)) = 4.55

		_RimSize("Rim Size", Range(0, 4)) = 0.6
		_RimBrightness("Rim Brightness", Range(0, 10)) = 10
	}

	CGINCLUDE //shared includes, variables, and functions
        #include "UnityCG.cginc"

	// User-specified properties
	sampler2D _MainTex;
	sampler2D _NoiseTex;
	fixed4 _Tint;
	float _Axis, _LineSpace, _Opacity;
	half _Density, _Density2, _Distortion, _LineSpeed,  _LineSpeed2, _Flicker, _FlickerStrength, _Brightness, _Brightness2, _RimSize, _RimBrightness;
	int _Quantize;

	float random(float2 seed)
	{
	   return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
	}

        //used to change the gradient of secondary lines
	float Quantize(float num, float quantize)
	{
	   return round(num * quantize) / quantize;
	}

	half3 AdjustContrast(half3 color, half contrast) {
		return saturate(lerp(half3(0.5, 0.5, 0.5), color, contrast));
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
			struct vertexOutput
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
			vertexOutput vert(vertexInput input)
			{
				vertexOutput output;

				float4x4 modelMatrix = unity_ObjectToWorld;
				float4x4 modelMatrixInverse = unity_WorldToObject;

                                //these values are used for rim lighting, similar to silhouette enhancement in hekpful basics
				output.normal = normalize(
					mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
				output.viewDir = normalize(_WorldSpaceCameraPos
					- mul(modelMatrix, input.vertex).xyz);

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

				//float4 adjustedDimension = 0.01 * sin(_LineSpeed * _Time.y + output.posWorld.x * _Density);
                                //changed vertex distortion to utilize a texture, rather than the sin function
                                //this (probably) saves on computation, and increases randomness
				float adjustedDimension = _Distortion * (0.5 - tex2Dlod(_NoiseTex, float4(output.posObj.xy + _Time.y, 0, 0)));

                                //performs distortion
				input.vertex.x += adjustedDimension;

				output.pos = UnityObjectToClipPos(input.vertex);
				output.screenPos = ComputeScreenPos(output.pos);
				//output.pos = UnityObjectToClipPos(newVertexPos);
				//float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
				//half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
				half3 worldN = UnityObjectToWorldNormal(input.normal);
				half3 shlight = ShadeSH9(float4(worldN, 1.0));

				return output;
			}

			float4 frag(vertexOutput input) : COLOR
			{
				    float4 col = tex2D(_MainTex, input.tex.xy);
					col.rgb = clamp(col.rgb * 0.5 + 0.5 * col.rgb * 3.2, 0.0, 1.0);
					col.rgb *= _Tint.rgb;

					float PrimaryPos = 0;

					if (_LineSpace == 0)
					{
						PrimaryPos = input.pos[_Axis];
					}
					else
					{
						PrimaryPos = input.posObj[_Axis];
						_Density *= 50;
					}

					 

					//col.rgb *= 0.9 + 0.1 * sin(_LineSpeed * _Time.y + input.pos.x * _Density);
					col.rgb *= 0.9 + 0.1 * sin(_LineSpeed * _Time.y + PrimaryPos.x * _Density);



					float adjustment = _Distortion * (0.5 - tex2D(_NoiseTex, input.posObj.xy));
					//lines
					//col.a = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((input.pos.x + adjustment)* _Density))) > 0.9 ? 1 : 0;



					//col.a = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((input.pos.x + adjustment)* _Density))) > 0.9 ? 1 : 0;
					col.a = (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((PrimaryPos + adjustment)* _Density))) > 0.9 ? 1 : 0;

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
					 
					//secondary flicker
					col.rgb *= 0.9 + 0.1 * _Brightness2 * round(sin(_LineSpeed2 * _Time.y + input.posWorld.y * _Density2) * _Quantize) / _Quantize;
					// Flicker
					col.rgb *= 0.97 + 0.03 * _FlickerStrength * sin(_Flicker * _Time.y);

					//rim lighting
					float3 normalDirection = normalize(input.normal);
					float3 viewDirection = normalize(input.viewDir);
					float newOpacity = min(1.0, .25
						/ abs(pow(dot(viewDirection, normalDirection), _RimSize)));
					newOpacity = newOpacity > 0.5 ? 1 : 0;
					//newOpacity = Quantize(newOpacity, 10);

					col += 0.1 * _RimBrightness * float4(_Tint.rgb * (newOpacity), 0);


					col.rgb *= _Brightness;
					col.a *= _Opacity;
					//col.a = 1;
					return col;
			}
			ENDCG
		}

	}
}
