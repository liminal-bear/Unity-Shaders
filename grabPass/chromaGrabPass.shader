Shader "ChromaticGrabPass"
{
	Properties
	{
		_TintColor("_TintColor", Color) = (1, 1, 1, 0.5)
		_ChromaticAberration ("Chromatic Aberration", Range(0.0,1.0)) = 0.001
		_Center ("Center",Range(0.0,0.5)) = 0.0
		_Cull ( "Face Culling", Int ) = 2
	}

	SubShader
	{
		Tags { "Queue" = "Transparent+1" }

		GrabPass
		{
			"_GrabTexture"
		}
		
		Pass
		{
			Cull [_Cull]

			CGPROGRAM
				#pragma target 3.0
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"
				#include "UnityStandardUtils.cginc"
				#include "UnityStandardInput.cginc"

				fixed _ChromaticAberration;
				fixed _Center;

				struct VS_INPUT
				{
					float4 vPosition : POSITION;
					float3 vNormal : NORMAL;
					float2 vTexcoord0 : TEXCOORD0;
					float4 vTangentUOs_flTangentVSign : TANGENT;
					float4 vColor : COLOR;
				};

				struct PS_INPUT
				{
					float4 vGrabPos : TEXCOORD0;
					float4 vPos : SV_POSITION;
					float4 vColor : COLOR;
					float2 vTexCoord0 : TEXCOORD1;
					float3 vNormalWs : TEXCOORD2;
					float3 vTangentUWs : TEXCOORD3;
					float3 vTangentVWs : TEXCOORD4;
				};

				PS_INPUT vert(VS_INPUT i)
				{
					PS_INPUT o;
					
					// Clip space position
					o.vPos = UnityObjectToClipPos(i.vPosition);
					
					// Grab position
					o.vGrabPos = ComputeGrabScreenPos(o.vPos);
					
					// World space normal
					o.vNormalWs = UnityObjectToWorldNormal(i.vNormal);

					// Tangent
					o.vTangentUWs.xyz = UnityObjectToWorldDir( i.vTangentUOs_flTangentVSign.xyz ); // World space tangentU
					o.vTangentVWs.xyz = cross( o.vNormalWs.xyz, o.vTangentUWs.xyz ) * i.vTangentUOs_flTangentVSign.w;

					// Texture coordinates
					o.vTexCoord0.xy = i.vTexcoord0.xy;

					// Color
					o.vColor = i.vColor;

					return o;
				}

				sampler2D _GrabTexture;
				float4 _TintColor;

				float4 frag(PS_INPUT i) : SV_Target
				{
					float2 rectangle = float2(i.vTexCoord0.x - _Center, i.vTexCoord0.y - _Center);
					float dist = sqrt(pow(rectangle.x,2) + pow(rectangle.y,2));

					float mov = _ChromaticAberration * dist;

					float4 uvR = float4(i.vGrabPos.x - mov, i.vGrabPos.y,i.vGrabPos.z,i.vGrabPos.w);
					float4 uvG = float4(i.vGrabPos.x + mov, i.vGrabPos.y,i.vGrabPos.z,i.vGrabPos.w);
					float4 uvB = float4(i.vGrabPos.x, i.vGrabPos.y - mov,i.vGrabPos.z,i.vGrabPos.w);

					// Sample grab texture
					float colorR = tex2Dproj(_GrabTexture, uvR).r;
					float colorG = tex2Dproj(_GrabTexture, uvG).g;
					float colorB = tex2Dproj(_GrabTexture, uvB).b;

					float4 color = float4(colorR,colorG,colorB,.8f);

					color *= _TintColor;

					return color;
				}
			ENDCG
		}
	}
}