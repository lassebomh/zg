const m = @import("../math/main.zig");

pub const GLEnum_ClearBuffer = enum(i32) {
    DEPTH_BUFFER_BIT = 0x00000100,
    STENCIL_BUFFER_BIT = 0x00000400,
    COLOR_BUFFER_BIT = 0x00004000,
};

pub const GLEnum_RenderPrimitive = enum(i32) {
    POINTS = 0x0000,
    LINES = 0x0001,
    LINE_LOOP = 0x0002,
    LINE_STRIP = 0x0003,
    TRIANGLES = 0x0004,
    TRIANGLE_STRIP = 0x0005,
    TRIANGLE_FAN = 0x0006,
};

pub const GLEnum_BlendMode = enum(i32) {
    ZERO = 0, // Passed to blendFunc or blendFuncSeparate to turn off a component.
    ONE = 1, // Passed to blendFunc or blendFuncSeparate to turn on a component.
    SRC_COLOR = 0x0300, // Passed to blendFunc or blendFuncSeparate to multiply a component by the source element's color.
    ONE_MINUS_SRC_COLOR = 0x0301, // Passed to blendFunc or blendFuncSeparate to multiply a component by one minus the source element's color.
    SRC_ALPHA = 0x0302, // Passed to blendFunc or blendFuncSeparate to multiply a component by the source's alpha.
    ONE_MINUS_SRC_ALPHA = 0x0303, // Passed to blendFunc or blendFuncSeparate to multiply a component by one minus the source's alpha.
    DST_ALPHA = 0x0304, // Passed to blendFunc or blendFuncSeparate to multiply a component by the destination's alpha.
    ONE_MINUS_DST_ALPHA = 0x0305, // Passed to blendFunc or blendFuncSeparate to multiply a component by one minus the destination's alpha.
    DST_COLOR = 0x0306, // Passed to blendFunc or blendFuncSeparate to multiply a component by the destination's color.
    ONE_MINUS_DST_COLOR = 0x0307, // Passed to blendFunc or blendFuncSeparate to multiply a component by one minus the destination's color.
    SRC_ALPHA_SATURATE = 0x0308, // Passed to blendFunc or blendFuncSeparate to multiply a component by the minimum of source's alpha or one minus the destination's alpha.
    CONSTANT_COLOR = 0x8001, // Passed to blendFunc or blendFuncSeparate to specify a constant color blend function.
    ONE_MINUS_CONSTANT_COLOR = 0x8002, // Passed to blendFunc or blendFuncSeparate to specify one minus a constant color blend function.
    CONSTANT_ALPHA = 0x8003, // Passed to blendFunc or blendFuncSeparate to specify a constant alpha blend function.
    ONE_MINUS_CONSTANT_ALPHA = 0x8004, // Passed to blendFunc or blendFuncSeparate to specify one minus a constant alpha blend function.
};

pub const GLEnum_BlendEquation = enum(i32) {
    FUNC_ADD = 0x8006, // Passed to blendEquation or blendEquationSeparate to set an addition blend function.
    FUNC_SUBTRACT = 0x800A, // Passed to blendEquation or blendEquationSeparate to specify a subtraction blend function (source - destination).
    FUNC_REVERSE_SUBTRACT = 0x800B, // Passed to blendEquation or blendEquationSeparate to specify a reverse subtraction blend function (destination - source).
};

pub const GLEnum_ParameterInformation = enum(i32) {
    BLEND_EQUATION = 0x8009, // Passed to getParameter to get the current RGB blend function.
    BLEND_EQUATION_RGB = 0x8009, // Passed to getParameter to get the current RGB blend function. Same as BLEND_EQUATION
    BLEND_EQUATION_ALPHA = 0x883D, // Passed to getParameter to get the current alpha blend function.
    BLEND_DST_RGB = 0x80C8, // Passed to getParameter to get the current destination RGB blend function.
    BLEND_SRC_RGB = 0x80C9, // Passed to getParameter to get the current source RGB blend function.
    BLEND_DST_ALPHA = 0x80CA, // Passed to getParameter to get the current destination alpha blend function.
    BLEND_SRC_ALPHA = 0x80CB, // Passed to getParameter to get the current source alpha blend function.
    BLEND_COLOR = 0x8005, // Passed to getParameter to return the current blend color.
    ARRAY_BUFFER_BINDING = 0x8894, // Passed to getParameter to get the array buffer binding.
    ELEMENT_ARRAY_BUFFER_BINDING = 0x8895, // Passed to getParameter to get the current element array buffer.
    LINE_WIDTH = 0x0B21, // Passed to getParameter to get the current lineWidth (set by the lineWidth method).
    ALIASED_POINT_SIZE_RANGE = 0x846D, // Passed to getParameter to get the current size of a point drawn with gl.POINTS
    ALIASED_LINE_WIDTH_RANGE = 0x846E, // Passed to getParameter to get the range of available widths for a line. The getParameter method then returns an array with two elements: the first element is the minimum width value and the second element is the maximum width value.
    CULL_FACE_MODE = 0x0B45, // Passed to getParameter to get the current value of cullFace. Should return FRONT, BACK, or FRONT_AND_BACK
    FRONT_FACE = 0x0B46, // Passed to getParameter to determine the current value of frontFace. Should return CW or CCW.
    DEPTH_RANGE = 0x0B70, // Passed to getParameter to return a length-2 array of floats giving the current depth range.
    DEPTH_WRITEMASK = 0x0B72, // Passed to getParameter to determine if the depth write mask is enabled.
    DEPTH_CLEAR_VALUE = 0x0B73, // Passed to getParameter to determine the current depth clear value.
    DEPTH_FUNC = 0x0B74, // Passed to getParameter to get the current depth function. Returns NEVER, ALWAYS, LESS, EQUAL, LEQUAL, GREATER, GEQUAL, or NOTEQUAL.
    STENCIL_CLEAR_VALUE = 0x0B91, // Passed to getParameter to get the value the stencil will be cleared to.
    STENCIL_FUNC = 0x0B92, // Passed to getParameter to get the current stencil function. Returns NEVER, ALWAYS, LESS, EQUAL, LEQUAL, GREATER, GEQUAL, or NOTEQUAL.
    STENCIL_FAIL = 0x0B94, // Passed to getParameter to get the current stencil fail function. Should return KEEP, REPLACE, INCR, DECR, INVERT, INCR_WRAP, or DECR_WRAP.
    STENCIL_PASS_DEPTH_FAIL = 0x0B95, // Passed to getParameter to get the current stencil fail function should the depth buffer test fail. Should return KEEP, REPLACE, INCR, DECR, INVERT, INCR_WRAP, or DECR_WRAP.
    STENCIL_PASS_DEPTH_PASS = 0x0B96, // Passed to getParameter to get the current stencil fail function should the depth buffer test pass. Should return KEEP, REPLACE, INCR, DECR, INVERT, INCR_WRAP, or DECR_WRAP.
    STENCIL_REF = 0x0B97, // Passed to getParameter to get the reference value used for stencil tests.
    STENCIL_VALUE_MASK = 0x0B93,
    STENCIL_WRITEMASK = 0x0B98,
    STENCIL_BACK_FUNC = 0x8800,
    STENCIL_BACK_FAIL = 0x8801,
    STENCIL_BACK_PASS_DEPTH_FAIL = 0x8802,
    STENCIL_BACK_PASS_DEPTH_PASS = 0x8803,
    STENCIL_BACK_REF = 0x8CA3,
    STENCIL_BACK_VALUE_MASK = 0x8CA4,
    STENCIL_BACK_WRITEMASK = 0x8CA5,
    VIEWPORT = 0x0BA2, // Returns an Int32Array with four elements for the current viewport dimensions.
    SCISSOR_BOX = 0x0C10, // Returns an Int32Array with four elements for the current scissor box dimensions.
    COLOR_CLEAR_VALUE = 0x0C22,
    COLOR_WRITEMASK = 0x0C23,
    UNPACK_ALIGNMENT = 0x0CF5,
    PACK_ALIGNMENT = 0x0D05,
    MAX_TEXTURE_SIZE = 0x0D33,
    MAX_VIEWPORT_DIMS = 0x0D3A,
    SUBPIXEL_BITS = 0x0D50,
    RED_BITS = 0x0D52,
    GREEN_BITS = 0x0D53,
    BLUE_BITS = 0x0D54,
    ALPHA_BITS = 0x0D55,
    DEPTH_BITS = 0x0D56,
    STENCIL_BITS = 0x0D57,
    POLYGON_OFFSET_UNITS = 0x2A00,
    POLYGON_OFFSET_FACTOR = 0x8038,
    TEXTURE_BINDING_2D = 0x8069,
    SAMPLE_BUFFERS = 0x80A8,
    SAMPLES = 0x80A9,
    SAMPLE_COVERAGE_VALUE = 0x80AA,
    SAMPLE_COVERAGE_INVERT = 0x80AB,
    COMPRESSED_TEXTURE_FORMATS = 0x86A3,
    VENDOR = 0x1F00,
    RENDERER = 0x1F01,
    VERSION = 0x1F02,
    IMPLEMENTATION_COLOR_READ_TYPE = 0x8B9A,
    IMPLEMENTATION_COLOR_READ_FORMAT = 0x8B9B,
    BROWSER_DEFAULT_WEBGL = 0x9244,

    // Webgl2

    READ_BUFFER = 0x0C02,
    UNPACK_ROW_LENGTH = 0x0CF2,
    UNPACK_SKIP_ROWS = 0x0CF3,
    UNPACK_SKIP_PIXELS = 0x0CF4,
    PACK_ROW_LENGTH = 0x0D02,
    PACK_SKIP_ROWS = 0x0D03,
    PACK_SKIP_PIXELS = 0x0D04,
    TEXTURE_BINDING_3D = 0x806A,
    UNPACK_SKIP_IMAGES = 0x806D,
    UNPACK_IMAGE_HEIGHT = 0x806E,
    MAX_3D_TEXTURE_SIZE = 0x8073,
    MAX_ELEMENTS_VERTICES = 0x80E8,
    MAX_ELEMENTS_INDICES = 0x80E9,
    MAX_TEXTURE_LOD_BIAS = 0x84FD,
    MAX_FRAGMENT_UNIFORM_COMPONENTS = 0x8B49,
    MAX_VERTEX_UNIFORM_COMPONENTS = 0x8B4A,
    MAX_ARRAY_TEXTURE_LAYERS = 0x88FF,
    MIN_PROGRAM_TEXEL_OFFSET = 0x8904,
    MAX_PROGRAM_TEXEL_OFFSET = 0x8905,
    MAX_VARYING_COMPONENTS = 0x8B4B,
    FRAGMENT_SHADER_DERIVATIVE_HINT = 0x8B8B,
    RASTERIZER_DISCARD = 0x8C89,
    VERTEX_ARRAY_BINDING = 0x85B5,
    MAX_VERTEX_OUTPUT_COMPONENTS = 0x9122,
    MAX_FRAGMENT_INPUT_COMPONENTS = 0x9125,
    MAX_SERVER_WAIT_TIMEOUT = 0x9111,
    MAX_ELEMENT_INDEX = 0x8D6B,
};

pub const GLEnum_Buffer = enum(i32) {
    STATIC_DRAW = 0x88E4, // Passed to bufferData as a hint about whether the contents of the buffer are likely to be used often and not change often.
    STREAM_DRAW = 0x88E0, // Passed to bufferData as a hint about whether the contents of the buffer are likely to not be used often.
    DYNAMIC_DRAW = 0x88E8, // Passed to bufferData as a hint about whether the contents of the buffer are likely to be used often and change often.
    ARRAY_BUFFER = 0x8892, // Passed to bindBuffer or bufferData to specify the type of buffer being used.
    ELEMENT_ARRAY_BUFFER = 0x8893, // Passed to bindBuffer or bufferData to specify the type of buffer being used.
    BUFFER_SIZE = 0x8764, // Passed to getBufferParameter to get a buffer's size.
    BUFFER_USAGE = 0x8765, // Passed to getBufferParameter to get the hint for the buffer passed in when it was created.

    // Webgl2:
    PIXEL_PACK_BUFFER = 0x88EB,
    PIXEL_UNPACK_BUFFER = 0x88EC,
    PIXEL_PACK_BUFFER_BINDING = 0x88ED,
    PIXEL_UNPACK_BUFFER_BINDING = 0x88EF,
    COPY_READ_BUFFER = 0x8F36,
    COPY_WRITE_BUFFER = 0x8F37,
    // COPY_READ_BUFFER_BINDING = 0x8F36, // Duplicates?
    // COPY_WRITE_BUFFER_BINDING = 0x8F37, // Duplicates?
};

pub const GLEnum_VertexAttribute = enum(i32) {
    CURRENT_VERTEX_ATTRIB = 0x8626, // Passed to getVertexAttrib to read back the current vertex attribute.
    VERTEX_ATTRIB_ARRAY_ENABLED = 0x8622,
    VERTEX_ATTRIB_ARRAY_SIZE = 0x8623,
    VERTEX_ATTRIB_ARRAY_STRIDE = 0x8624,
    VERTEX_ATTRIB_ARRAY_TYPE = 0x8625,
    VERTEX_ATTRIB_ARRAY_NORMALIZED = 0x886A,
    VERTEX_ATTRIB_ARRAY_POINTER = 0x8645,
    VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F,

    // Webgl2:
    VERTEX_ATTRIB_ARRAY_INTEGER = 0x88FD,
    VERTEX_ATTRIB_ARRAY_DIVISOR = 0x88FE,
};

pub const GLEnum_Culling = enum(i32) {
    FRONT = 0x0404, // Passed to cullFace to specify that only front faces should be culled.
    BACK = 0x0405, // Passed to cullFace to specify that only back faces should be culled.
    FRONT_AND_BACK = 0x0408, // Passed to cullFace to specify that front and back faces should be culled.
};

pub const GLEnum_EnableDisable = enum(i32) {
    BLEND = 0x0BE2, // Passed to enable/disable to turn on/off blending. Can also be used with getParameter to find the current blending method.
    CULL_FACE = 0x0B44, // Passed to enable/disable to turn on/off culling. Can also be used with getParameter to find the current culling method.
    DEPTH_TEST = 0x0B71, // Passed to enable/disable to turn on/off the depth test. Can also be used with getParameter to query the depth test.
    DITHER = 0x0BD0, // Passed to enable/disable to turn on/off dithering. Can also be used with getParameter to find the current dithering method.
    POLYGON_OFFSET_FILL = 0x8037, // Passed to enable/disable to turn on/off the polygon offset. Useful for rendering hidden-line images, decals, and solids with highlighted edges. Can also be used with getParameter to query the scissor test.
    SAMPLE_ALPHA_TO_COVERAGE = 0x809E, // Passed to enable/disable to turn on/off the alpha to coverage. Used in multi-sampling alpha channels.
    SAMPLE_COVERAGE = 0x80A0, // Passed to enable/disable to turn on/off the sample coverage. Used in multi-sampling.
    SCISSOR_TEST = 0x0C11, // Passed to enable/disable to turn on/off the scissor test. Can also be used with getParameter to query the scissor test.
    STENCIL_TEST = 0x0B90, // Passed to enable/disable to turn on/off the stencil test. Can also be used with getParameter to query the stencil test.
};

pub const GLEnum_Error = enum(i32) {
    NO_ERROR = 0, // Returned from getError.
    INVALID_ENUM = 0x0500, // Returned from getError.
    INVALID_VALUE = 0x0501, // Returned from getError.
    INVALID_OPERATION = 0x0502, // Returned from getError.
    OUT_OF_MEMORY = 0x0505, // Returned from getError.
    CONTEXT_LOST_WEBGL = 0x9242, // Returned from getError.
};

pub const GLEnum_FrontFaceDirection = enum(i32) {
    CW = 0x0900, //  Passed to frontFace to specify the front face of a polygon is drawn in the clockwise direction
    CCW = 0x0901, //  Passed to frontFace to specify the front face of a polygon is drawn in the counter clockwise direction
};

pub const GLEnum_Hint = enum(i32) {
    DONT_CARE = 0x1100, // There is no preference for this behavior.
    FASTEST = 0x1101, // The most efficient behavior should be used.
    NICEST = 0x1102, // The most correct or the highest quality option should be used.
    GENERATE_MIPMAP_HINT = 0x8192, // Hint for the quality of filtering when generating mipmap images with WebGLRenderingContext.generateMipmap().
};

pub const GLEnum_DataType = enum(i32) {
    UNSIGNED_BYTE = 0x1401,
    UNSIGNED_SHORT_4_4_4_4 = 0x8033,
    UNSIGNED_SHORT_5_5_5_1 = 0x8034,
    UNSIGNED_SHORT_5_6_5 = 0x8363,
    BYTE = 0x1400,
    SHORT = 0x1402,
    UNSIGNED_SHORT = 0x1403,
    INT = 0x1404,
    UNSIGNED_INT = 0x1405,
    FLOAT = 0x1406,

    // Webgl2
    FLOAT_MAT2x3 = 0x8B65,
    FLOAT_MAT2x4 = 0x8B66,
    FLOAT_MAT3x2 = 0x8B67,
    FLOAT_MAT3x4 = 0x8B68,
    FLOAT_MAT4x2 = 0x8B69,
    FLOAT_MAT4x3 = 0x8B6A,
    UNSIGNED_INT_VEC2 = 0x8DC6,
    UNSIGNED_INT_VEC3 = 0x8DC7,
    UNSIGNED_INT_VEC4 = 0x8DC8,
    UNSIGNED_NORMALIZED = 0x8C17,
    SIGNED_NORMALIZED = 0x8F9C,
    UNSIGNED_INT_2_10_10_10_REV = 0x8368,
    UNSIGNED_INT_10F_11F_11F_REV = 0x8C3B,
    UNSIGNED_INT_5_9_9_9_REV = 0x8C3E,
    FLOAT_32_UNSIGNED_INT_24_8_REV = 0x8DAD,
    UNSIGNED_INT_24_8 = 0x84FA,
    HALF_FLOAT = 0x140B,
    RG = 0x8227,
    RG_INTEGER = 0x8228,
    INT_2_10_10_10_REV = 0x8D9F,
};

pub const GLEnum_PixelFormat = enum(i32) {
    DEPTH_COMPONENT = 0x1902,
    ALPHA = 0x1906,
    RGB = 0x1907,
    RGBA = 0x1908,
    LUMINANCE = 0x1909,
    LUMINANCE_ALPHA = 0x190A,
};

pub const GLEnum_Shader = enum(i32) {
    FRAGMENT_SHADER = 0x8B30, // Passed to createShader to define a fragment shader.
    VERTEX_SHADER = 0x8B31, // Passed to createShader to define a vertex shader
    COMPILE_STATUS = 0x8B81, // Passed to getShaderParameter to get the status of the compilation. Returns false if the shader was not compiled. You can then query getShaderInfoLog to find the exact error
    DELETE_STATUS = 0x8B80, // Passed to getShaderParameter to determine if a shader was deleted via deleteShader. Returns true if it was, false otherwise.
    LINK_STATUS = 0x8B82, // Passed to getProgramParameter after calling linkProgram to determine if a program was linked correctly. Returns false if there were errors. Use getProgramInfoLog to find the exact error.
    VALIDATE_STATUS = 0x8B83, // Passed to getProgramParameter after calling validateProgram to determine if it is valid. Returns false if errors were found.
    ATTACHED_SHADERS = 0x8B85, // Passed to getProgramParameter after calling attachShader to determine if the shader was attached correctly. Returns false if errors occurred.
    ACTIVE_ATTRIBUTES = 0x8B89, // Passed to getProgramParameter to get the number of attributes active in a program.
    ACTIVE_UNIFORMS = 0x8B86, // Passed to getProgramParameter to get the number of uniforms active in a program.
    MAX_VERTEX_ATTRIBS = 0x8869, // The maximum number of entries possible in the vertex attribute list.
    MAX_VERTEX_UNIFORM_VECTORS = 0x8DFB,
    MAX_VARYING_VECTORS = 0x8DFC,
    MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D,
    MAX_VERTEX_TEXTURE_IMAGE_UNITS = 0x8B4C,
    MAX_TEXTURE_IMAGE_UNITS = 0x8872, // Implementation-dependent number of maximum texture units. At least 8.
    MAX_FRAGMENT_UNIFORM_VECTORS = 0x8DFD,
    SHADER_TYPE = 0x8B4F,
    SHADING_LANGUAGE_VERSION = 0x8B8C,
    CURRENT_PROGRAM = 0x8B8D,
};

pub const GLEnum_DepthOrStencilTest = enum(i32) {
    NEVER = 0x0200, // Passed to depthFunction or stencilFunction to specify depth or stencil tests will never pass, i.e., nothing will be drawn.
    LESS = 0x0201, // Passed to depthFunction or stencilFunction to specify depth or stencil tests will pass if the new depth value is less than the stored value.
    EQUAL = 0x0202, // Passed to depthFunction or stencilFunction to specify depth or stencil tests will pass if the new depth value is equals to the stored value.
    LEQUAL = 0x0203, // Passed to depthFunction or stencilFunction to specify depth or stencil tests will pass if the new depth value is less than or equal to the stored value.
    GREATER = 0x0204, // Passed to depthFunction or stencilFunction to specify depth or stencil tests will pass if the new depth value is greater than the stored value.
    NOTEQUAL = 0x0205, // Passed to depthFunction or stencilFunction to specify depth or stencil tests will pass if the new depth value is not equal to the stored value.
    GEQUAL = 0x0206, // Passed to depthFunction or stencilFunction to specify depth or stencil tests will pass if the new depth value is greater than or equal to the stored value.
    ALWAYS = 0x0207, // Passed to depthFunction or stencilFunction to specify depth or stencil tests will always pass, i.e., pixels will be drawn in the order they are drawn.
};

pub const GLEnum_StencilAction = enum(i32) {
    KEEP = 0x1E00,
    REPLACE = 0x1E01,
    INCR = 0x1E02,
    DECR = 0x1E03,
    INVERT = 0x150A,
    INCR_WRAP = 0x8507,
    DECR_WRAP = 0x8508,
};

pub const GLEnum_Texture = enum(i32) {
    NEAREST = 0x2600,
    LINEAR = 0x2601,
    NEAREST_MIPMAP_NEAREST = 0x2700,
    LINEAR_MIPMAP_NEAREST = 0x2701,
    NEAREST_MIPMAP_LINEAR = 0x2702,
    LINEAR_MIPMAP_LINEAR = 0x2703,
    TEXTURE_MAG_FILTER = 0x2800,
    TEXTURE_MIN_FILTER = 0x2801,
    TEXTURE_WRAP_S = 0x2802,
    TEXTURE_WRAP_T = 0x2803,
    TEXTURE_2D = 0x0DE1,
    TEXTURE = 0x1702,
    TEXTURE_CUBE_MAP = 0x8513,
    TEXTURE_BINDING_CUBE_MAP = 0x8514,
    TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515,
    TEXTURE_CUBE_MAP_NEGATIVE_X = 0x8516,
    TEXTURE_CUBE_MAP_POSITIVE_Y = 0x8517,
    TEXTURE_CUBE_MAP_NEGATIVE_Y = 0x8518,
    TEXTURE_CUBE_MAP_POSITIVE_Z = 0x8519,
    TEXTURE_CUBE_MAP_NEGATIVE_Z = 0x851A,
    MAX_CUBE_MAP_TEXTURE_SIZE = 0x851C,
    TEXTURE0 = 0x84C0,
    TEXTURE1 = 0x84C1,
    TEXTURE2 = 0x84C2,
    TEXTURE3 = 0x84C3,
    TEXTURE4 = 0x84C4,
    TEXTURE5 = 0x84C5,
    TEXTURE6 = 0x84C6,
    TEXTURE7 = 0x84C7,
    TEXTURE8 = 0x84C8,
    TEXTURE9 = 0x84C9,
    TEXTURE10 = 0x84CA,
    TEXTURE11 = 0x84CB,
    TEXTURE12 = 0x84CC,
    TEXTURE13 = 0x84CD,
    TEXTURE14 = 0x84CE,
    TEXTURE15 = 0x84CF,
    TEXTURE16 = 0x84D0,
    TEXTURE17 = 0x84D1,
    TEXTURE18 = 0x84D2,
    TEXTURE19 = 0x84D3,
    TEXTURE20 = 0x84D4,
    TEXTURE21 = 0x84D5,
    TEXTURE22 = 0x84D6,
    TEXTURE23 = 0x84D7,
    TEXTURE24 = 0x84D8,
    TEXTURE25 = 0x84D9,
    TEXTURE26 = 0x84DA,
    TEXTURE27 = 0x84DB,
    TEXTURE28 = 0x84DC,
    TEXTURE29 = 0x84DD,
    TEXTURE30 = 0x84DE,
    TEXTURE31 = 0x84DF,
    ACTIVE_TEXTURE = 0x84E0, // The current active texture unit.
    REPEAT = 0x2901,
    CLAMP_TO_EDGE = 0x812F,
    MIRRORED_REPEAT = 0x8370,

    DEPTH_COMPONENT24 = 0x81A6,

    // Webgl2:

    RED = 0x1903,
    RGB8 = 0x8051,
    RGBA8 = 0x8058,
    RGB10_A2 = 0x8059,
    TEXTURE_3D = 0x806F,
    TEXTURE_WRAP_R = 0x8072,
    TEXTURE_MIN_LOD = 0x813A,
    TEXTURE_MAX_LOD = 0x813B,
    TEXTURE_BASE_LEVEL = 0x813C,
    TEXTURE_MAX_LEVEL = 0x813D,
    TEXTURE_COMPARE_MODE = 0x884C,
    TEXTURE_COMPARE_FUNC = 0x884D,
    SRGB = 0x8C40,
    SRGB8 = 0x8C41,
    SRGB8_ALPHA8 = 0x8C43,
    COMPARE_REF_TO_TEXTURE = 0x884E,
    RGBA32F = 0x8814,
    RGB32F = 0x8815,
    RGBA16F = 0x881A,
    RGB16F = 0x881B,
    TEXTURE_2D_ARRAY = 0x8C1A,
    TEXTURE_BINDING_2D_ARRAY = 0x8C1D,
    R11F_G11F_B10F = 0x8C3A,
    RGB9_E5 = 0x8C3D,
    RGBA32UI = 0x8D70,
    RGB32UI = 0x8D71,
    RGBA16UI = 0x8D76,
    RGB16UI = 0x8D77,
    RGBA8UI = 0x8D7C,
    RGB8UI = 0x8D7D,
    RGBA32I = 0x8D82,
    RGB32I = 0x8D83,
    RGBA16I = 0x8D88,
    RGB16I = 0x8D89,
    RGBA8I = 0x8D8E,
    RGB8I = 0x8D8F,
    RED_INTEGER = 0x8D94,
    RGB_INTEGER = 0x8D98,
    RGBA_INTEGER = 0x8D99,
    R8 = 0x8229,
    RG8 = 0x822B,
    R16F = 0x822D,
    R32F = 0x822E,
    RG16F = 0x822F,
    RG32F = 0x8230,
    R8I = 0x8231,
    R8UI = 0x8232,
    R16I = 0x8233,
    R16UI = 0x8234,
    R32I = 0x8235,
    R32UI = 0x8236,
    RG8I = 0x8237,
    RG8UI = 0x8238,
    RG16I = 0x8239,
    RG16UI = 0x823A,
    RG32I = 0x823B,
    RG32UI = 0x823C,
    R8_SNORM = 0x8F94,
    RG8_SNORM = 0x8F95,
    RGB8_SNORM = 0x8F96,
    RGBA8_SNORM = 0x8F97,
    RGB10_A2UI = 0x906F,
    TEXTURE_IMMUTABLE_FORMAT = 0x912F,
    TEXTURE_IMMUTABLE_LEVELS = 0x82DF,
};

pub const GLEnum_UniformType = enum(i32) {
    FLOAT_VEC2 = 0x8B50,
    FLOAT_VEC3 = 0x8B51,
    FLOAT_VEC4 = 0x8B52,
    INT_VEC2 = 0x8B53,
    INT_VEC3 = 0x8B54,
    INT_VEC4 = 0x8B55,
    BOOL = 0x8B56,
    BOOL_VEC2 = 0x8B57,
    BOOL_VEC3 = 0x8B58,
    BOOL_VEC4 = 0x8B59,
    FLOAT_MAT2 = 0x8B5A,
    FLOAT_MAT3 = 0x8B5B,
    FLOAT_MAT4 = 0x8B5C,
    SAMPLER_2D = 0x8B5E,
    SAMPLER_CUBE = 0x8B60,
};

pub const GLEnum_Uniform = enum(i32) {
    UNIFORM_BUFFER = 0x8A11,
    UNIFORM_BUFFER_BINDING = 0x8A28,
    UNIFORM_BUFFER_START = 0x8A29,
    UNIFORM_BUFFER_SIZE = 0x8A2A,
    MAX_VERTEX_UNIFORM_BLOCKS = 0x8A2B,
    MAX_FRAGMENT_UNIFORM_BLOCKS = 0x8A2D,
    MAX_COMBINED_UNIFORM_BLOCKS = 0x8A2E,
    MAX_UNIFORM_BUFFER_BINDINGS = 0x8A2F,
    MAX_UNIFORM_BLOCK_SIZE = 0x8A30,
    MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS = 0x8A31,
    MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS = 0x8A33,
    UNIFORM_BUFFER_OFFSET_ALIGNMENT = 0x8A34,
    ACTIVE_UNIFORM_BLOCKS = 0x8A36,
    UNIFORM_TYPE = 0x8A37,
    UNIFORM_SIZE = 0x8A38,
    UNIFORM_BLOCK_INDEX = 0x8A3A,
    UNIFORM_OFFSET = 0x8A3B,
    UNIFORM_ARRAY_STRIDE = 0x8A3C,
    UNIFORM_MATRIX_STRIDE = 0x8A3D,
    UNIFORM_IS_ROW_MAJOR = 0x8A3E,
    UNIFORM_BLOCK_BINDING = 0x8A3F,
    UNIFORM_BLOCK_DATA_SIZE = 0x8A40,
    UNIFORM_BLOCK_ACTIVE_UNIFORMS = 0x8A42,
    UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES = 0x8A43,
    UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER = 0x8A44,
    UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER = 0x8A46,
};

pub const GLEnum_ShaderPrecisionSpecifiedType = enum(i32) {
    LOW_FLOAT = 0x8DF0,
    MEDIUM_FLOAT = 0x8DF1,
    HIGH_FLOAT = 0x8DF2,
    LOW_INT = 0x8DF3,
    MEDIUM_INT = 0x8DF4,
    HIGH_INT = 0x8DF5,
};

pub const GLEnum_FramebufferOrRenderbuffer = enum(i32) {
    FRAMEBUFFER = 0x8D40,
    RENDERBUFFER = 0x8D41,
    RGBA4 = 0x8056,
    RGB5_A1 = 0x8057,
    RGB565 = 0x8D62,
    DEPTH_COMPONENT16 = 0x81A5,
    STENCIL_INDEX8 = 0x8D48,
    DEPTH_STENCIL = 0x84F9,
    RENDERBUFFER_WIDTH = 0x8D42,
    RENDERBUFFER_HEIGHT = 0x8D43,
    RENDERBUFFER_INTERNAL_FORMAT = 0x8D44,
    RENDERBUFFER_RED_SIZE = 0x8D50,
    RENDERBUFFER_GREEN_SIZE = 0x8D51,
    RENDERBUFFER_BLUE_SIZE = 0x8D52,
    RENDERBUFFER_ALPHA_SIZE = 0x8D53,
    RENDERBUFFER_DEPTH_SIZE = 0x8D54,
    RENDERBUFFER_STENCIL_SIZE = 0x8D55,
    FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = 0x8CD0,
    FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = 0x8CD1,
    FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = 0x8CD2,
    FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = 0x8CD3,
    COLOR_ATTACHMENT0 = 0x8CE0,
    DEPTH_ATTACHMENT = 0x8D00,
    STENCIL_ATTACHMENT = 0x8D20,
    DEPTH_STENCIL_ATTACHMENT = 0x821A,
    NONE = 0,
    FRAMEBUFFER_COMPLETE = 0x8CD5,
    FRAMEBUFFER_INCOMPLETE_ATTACHMENT = 0x8CD6,
    FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = 0x8CD7,
    FRAMEBUFFER_INCOMPLETE_DIMENSIONS = 0x8CD9,
    FRAMEBUFFER_UNSUPPORTED = 0x8CDD,
    FRAMEBUFFER_BINDING = 0x8CA6,
    RENDERBUFFER_BINDING = 0x8CA7,
    MAX_RENDERBUFFER_SIZE = 0x84E8,
    INVALID_FRAMEBUFFER_OPERATION = 0x0506,

    // webgl2

    FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING = 0x8210,
    FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE = 0x8211,
    FRAMEBUFFER_ATTACHMENT_RED_SIZE = 0x8212,
    FRAMEBUFFER_ATTACHMENT_GREEN_SIZE = 0x8213,
    FRAMEBUFFER_ATTACHMENT_BLUE_SIZE = 0x8214,
    FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE = 0x8215,
    FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE = 0x8216,
    FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE = 0x8217,
    FRAMEBUFFER_DEFAULT = 0x8218,
    DEPTH24_STENCIL8 = 0x88F0,
    // DRAW_FRAMEBUFFER_BINDING = 0x8CA6,
    READ_FRAMEBUFFER = 0x8CA8,
    DRAW_FRAMEBUFFER = 0x8CA9,
    READ_FRAMEBUFFER_BINDING = 0x8CAA,
    RENDERBUFFER_SAMPLES = 0x8CAB,
    FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER = 0x8CD4,
    FRAMEBUFFER_INCOMPLETE_MULTISAMPLE = 0x8D56,
};

pub const GLEnum_PixelStorageMode = enum(i32) {
    UNPACK_FLIP_Y_WEBGL = 0x9240,
    UNPACK_PREMULTIPLY_ALPHA_WEBGL = 0x9241,
    UNPACK_COLORSPACE_CONVERSION_WEBGL = 0x9243,
};

pub const GLEnum_Query = enum(i32) {
    CURRENT_QUERY = 0x8865,
    QUERY_RESULT = 0x8866,
    QUERY_RESULT_AVAILABLE = 0x8867,
    ANY_SAMPLES_PASSED = 0x8C2F,
    ANY_SAMPLES_PASSED_CONSERVATIVE = 0x8D6A,
};

pub const GLEnum_DrawBuffer = enum(i32) {
    MAX_DRAW_BUFFERS = 0x8824,
    DRAW_BUFFER0 = 0x8825,
    DRAW_BUFFER1 = 0x8826,
    DRAW_BUFFER2 = 0x8827,
    DRAW_BUFFER3 = 0x8828,
    DRAW_BUFFER4 = 0x8829,
    DRAW_BUFFER5 = 0x882A,
    DRAW_BUFFER6 = 0x882B,
    DRAW_BUFFER7 = 0x882C,
    DRAW_BUFFER8 = 0x882D,
    DRAW_BUFFER9 = 0x882E,
    DRAW_BUFFER10 = 0x882F,
    DRAW_BUFFER11 = 0x8830,
    DRAW_BUFFER12 = 0x8831,
    DRAW_BUFFER13 = 0x8832,
    DRAW_BUFFER14 = 0x8833,
    DRAW_BUFFER15 = 0x8834,
    MAX_COLOR_ATTACHMENTS = 0x8CDF,
    COLOR_ATTACHMENT1 = 0x8CE1,
    COLOR_ATTACHMENT2 = 0x8CE2,
    COLOR_ATTACHMENT3 = 0x8CE3,
    COLOR_ATTACHMENT4 = 0x8CE4,
    COLOR_ATTACHMENT5 = 0x8CE5,
    COLOR_ATTACHMENT6 = 0x8CE6,
    COLOR_ATTACHMENT7 = 0x8CE7,
    COLOR_ATTACHMENT8 = 0x8CE8,
    COLOR_ATTACHMENT9 = 0x8CE9,
    COLOR_ATTACHMENT10 = 0x8CEA,
    COLOR_ATTACHMENT11 = 0x8CEB,
    COLOR_ATTACHMENT12 = 0x8CEC,
    COLOR_ATTACHMENT13 = 0x8CED,
    COLOR_ATTACHMENT14 = 0x8CEE,
    COLOR_ATTACHMENT15 = 0x8CEF,
};

pub const GLEnum_Sampler = enum(i32) {
    SAMPLER_3D = 0x8B5F,
    SAMPLER_2D_SHADOW = 0x8B62,
    SAMPLER_2D_ARRAY = 0x8DC1,
    SAMPLER_2D_ARRAY_SHADOW = 0x8DC4,
    SAMPLER_CUBE_SHADOW = 0x8DC5,
    INT_SAMPLER_2D = 0x8DCA,
    INT_SAMPLER_3D = 0x8DCB,
    INT_SAMPLER_CUBE = 0x8DCC,
    INT_SAMPLER_2D_ARRAY = 0x8DCF,
    UNSIGNED_INT_SAMPLER_2D = 0x8DD2,
    UNSIGNED_INT_SAMPLER_3D = 0x8DD3,
    UNSIGNED_INT_SAMPLER_CUBE = 0x8DD4,
    UNSIGNED_INT_SAMPLER_2D_ARRAY = 0x8DD7,
    MAX_SAMPLES = 0x8D57,
    SAMPLER_BINDING = 0x8919,
};

pub const GLEnum_TransformFeedback = enum(i32) {
    TRANSFORM_FEEDBACK_BUFFER_MODE = 0x8C7F,
    MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS = 0x8C80,
    TRANSFORM_FEEDBACK_VARYINGS = 0x8C83,
    TRANSFORM_FEEDBACK_BUFFER_START = 0x8C84,
    TRANSFORM_FEEDBACK_BUFFER_SIZE = 0x8C85,
    TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN = 0x8C88,
    MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS = 0x8C8A,
    MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS = 0x8C8B,
    INTERLEAVED_ATTRIBS = 0x8C8C,
    SEPARATE_ATTRIBS = 0x8C8D,
    TRANSFORM_FEEDBACK_BUFFER = 0x8C8E,
    TRANSFORM_FEEDBACK_BUFFER_BINDING = 0x8C8F,
    TRANSFORM_FEEDBACK = 0x8E22,
    TRANSFORM_FEEDBACK_PAUSED = 0x8E23,
    TRANSFORM_FEEDBACK_ACTIVE = 0x8E24,
    TRANSFORM_FEEDBACK_BINDING = 0x8E25,
};

pub const GLEnum_SyncObject = enum(i32) {
    OBJECT_TYPE = 0x9112,
    SYNC_CONDITION = 0x9113,
    SYNC_STATUS = 0x9114,
    SYNC_FLAGS = 0x9115,
    SYNC_FENCE = 0x9116,
    SYNC_GPU_COMMANDS_COMPLETE = 0x9117,
    UNSIGNALED = 0x9118,
    SIGNALED = 0x9119,
    ALREADY_SIGNALED = 0x911A,
    TIMEOUT_EXPIRED = 0x911B,
    CONDITION_SATISFIED = 0x911C,
    WAIT_FAILED = 0x911D,
    SYNC_FLUSH_COMMANDS_BIT = 0x00000001,
};

pub const GLEnum_Miscellaneous = enum(i32) {
    COLOR = 0x1800,
    DEPTH = 0x1801,
    STENCIL = 0x1802,
    MIN = 0x8007,
    MAX = 0x8008,
    DEPTH_COMPONENT24 = 0x81A6,
    STREAM_READ = 0x88E1,
    STREAM_COPY = 0x88E2,
    STATIC_READ = 0x88E5,
    STATIC_COPY = 0x88E6,
    DYNAMIC_READ = 0x88E9,
    DYNAMIC_COPY = 0x88EA,
    DEPTH_COMPONENT32F = 0x8CAC,
    DEPTH32F_STENCIL8 = 0x8CAD,
    INVALID_INDEX = 0xFFFFFFFF,
    TIMEOUT_IGNORED = -1,
    MAX_CLIENT_WAIT_TIMEOUT_WEBGL = 0x9247,
};

pub extern fn createShader(shaderType: GLEnum_Shader) *anyopaque;
extern fn _shaderSource(shader: *anyopaque, sourcePtr: [*]const u8, sourceLen: i32) void;
pub fn shaderSource(shader: *anyopaque, source: []const u8) void {
    _shaderSource(shader, source.ptr, @intCast(source.len));
}

pub extern fn compileShader(shader: *anyopaque) void;
pub extern fn createProgram() *anyopaque;
pub extern fn attachShader(program: *anyopaque, shader: *anyopaque) void;
pub extern fn linkProgram(program: *anyopaque) void;
pub extern fn createVertexArray() *anyopaque;
extern fn _bindVertexArray(vao: *anyopaque) void;
extern fn _unbindVertexArray() void;
pub fn bindVertexArray(vao: ?*anyopaque) void {
    if (vao != null) {
        _bindVertexArray(vao.?);
    } else {
        _unbindVertexArray();
    }
}

pub extern fn createBuffer() *anyopaque;
pub extern fn bindBuffer(target: GLEnum_Buffer, buffer: *anyopaque) void;
extern fn _bufferDataf(target: GLEnum_Buffer, dataPtr: [*]const f32, dataLen: i32, usage: GLEnum_Buffer) void;
pub fn bufferDataF32(target: GLEnum_Buffer, data: []const f32, usage: GLEnum_Buffer) void {
    _bufferDataf(target, data.ptr, @intCast(data.len), usage);
}
pub fn bufferDataV3(target: GLEnum_Buffer, data: [][3]f32, usage: GLEnum_Buffer) void {
    _bufferDataf(target, @ptrCast(data.ptr), @intCast(data.len * 3), usage);
}
pub fn bufferDataV4(target: GLEnum_Buffer, data: []const m.Vec4, usage: GLEnum_Buffer) void {
    _bufferDataf(target, @ptrCast(data.ptr), @intCast(data.len * 4), usage);
}
pub fn bufferDataM4x4(target: GLEnum_Buffer, data: []const m.Mat4x4, usage: GLEnum_Buffer) void {
    _bufferDataf(target, @ptrCast(data.ptr), @intCast(data.len * 16), usage);
}
extern fn _bufferDatau(target: GLEnum_Buffer, dataPtr: [*]const u32, dataLen: i32, usage: GLEnum_Buffer) void;
pub fn bufferDataU32(target: GLEnum_Buffer, data: []const u32, usage: GLEnum_Buffer) void {
    _bufferDatau(target, data.ptr, @intCast(data.len), usage);
}

extern fn _getAttribLocation(program: *anyopaque, namePtr: [*]const u8, nameLen: i32) i32;
pub fn getAttribLocation(program: *anyopaque, name: []const u8) i32 {
    return _getAttribLocation(program, name.ptr, @intCast(name.len));
}

pub extern fn enableVertexAttribArray(attribLocation: i32) void;

extern fn _vertexAttribPointer(index: i32, size: i32, type: GLEnum_DataType, normalized: i32, stride: i32, offset: i32) void;
pub fn vertexAttribPointer(index: i32, size: i32, _type: GLEnum_DataType, normalized: bool, stride: i32, offset: i32) void {
    _vertexAttribPointer(index, size, _type, if (normalized) 1 else 0, stride, offset);
}

pub extern fn useProgram(program: *anyopaque) void;
pub extern fn drawArrays(mode: GLEnum_RenderPrimitive, first: i32, count: i32) void;

extern fn _getUniformLocation(program: *anyopaque, namePtr: [*]const u8, nameLen: i32) *anyopaque;
pub fn getUniformLocation(program: *anyopaque, name: []const u8) *anyopaque {
    return _getUniformLocation(program, name.ptr, @intCast(name.len));
}

extern fn _uniformMatrix4fv(uniform: *anyopaque, transpose: i32, valuePtr: [*]const f32, valueLen: i32) void;
pub fn uniformMatrix4fv(uniform: *anyopaque, transpose: bool, value: m.Mat4x4) void {
    _uniformMatrix4fv(uniform, if (transpose) 1 else 0, @ptrCast(&value), 16);
}
pub extern fn uniform1f(uniform: *anyopaque, value: f32) void;
pub extern fn uniform1i(uniform: *anyopaque, value: i32) void;
pub extern fn uniform2f(uniform: *anyopaque, x: f32, y: f32) void;

pub extern fn clear(mask: i32) void;
pub extern fn enable(cap: GLEnum_EnableDisable) void;
pub extern fn disable(cap: GLEnum_EnableDisable) void;

pub extern fn drawElements(mode: GLEnum_RenderPrimitive, count: i32, type: GLEnum_DataType, offset: i32) void;

pub extern fn drawElementsInstanced(mode: GLEnum_RenderPrimitive, count: i32, type: GLEnum_DataType, offset: i32, instanceCount: i32) void;
pub extern fn vertexAttribDivisor(index: i32, divisor: i32) void;

pub extern fn createTexture() *anyopaque;
pub extern fn bindTexture(target: GLEnum_Texture, texture: *anyopaque) void;
pub extern fn texParameteri(target: GLEnum_Texture, pname: GLEnum_Texture, param: GLEnum_Texture) void;
pub extern fn createFrameBuffer() *anyopaque;

extern fn _bindFramebuffer(target: GLEnum_FramebufferOrRenderbuffer, framebuffer: *anyopaque) void;
extern fn _unbindFramebuffer(target: GLEnum_FramebufferOrRenderbuffer) void;
pub fn bindFramebuffer(target: GLEnum_FramebufferOrRenderbuffer, framebuffer: ?*anyopaque) void {
    if (framebuffer != null) {
        _bindFramebuffer(target, framebuffer.?);
    } else {
        _unbindFramebuffer(target);
    }
}
pub extern fn framebufferTexture2D(target: GLEnum_FramebufferOrRenderbuffer, attachment: GLEnum_FramebufferOrRenderbuffer, textarget: GLEnum_Texture, texture: *anyopaque, level: i32) void;
pub extern fn activeTexture(target: GLEnum_Texture) void;
pub extern fn texImage2D(target: GLEnum_Texture, level: i32, internalformat: GLEnum_Texture, width: i32, height: i32, border: i32, format: GLEnum_PixelFormat, type: GLEnum_DataType) void;

pub extern fn viewport(x: i32, y: i32, w: i32, h: i32) void;
