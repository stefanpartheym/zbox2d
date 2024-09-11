const std = @import("std");
const zb = @import("zbox2d-native");

pub fn main() !void {
    std.debug.print("# zbox2d-example #\n", .{});

    var worldDef = zb.b2DefaultWorldDef();
    worldDef.gravity = .{ .x = 0.0, .y = -10.0 };
    const worldId = zb.b2CreateWorld(&worldDef);

    var groundBodyDef = zb.b2DefaultBodyDef();
    groundBodyDef.position = zb.b2Vec2{ .x = 0.0, .y = -10.0 };

    const groundId = zb.b2CreateBody(worldId, &groundBodyDef);

    const groundBox = zb.b2MakeBox(50.0, 10.0);

    const groundShapeDef = zb.b2DefaultShapeDef();

    _ = zb.b2CreatePolygonShape(groundId, &groundShapeDef, &groundBox);

    var bodyDef = zb.b2DefaultBodyDef();
    bodyDef.type = zb.b2_dynamicBody;
    bodyDef.position = zb.b2Vec2{ .x = 0.0, .y = 4.0 };
    const bodyId = zb.b2CreateBody(worldId, &bodyDef);

    const dynamicBox = zb.b2MakeBox(1.0, 1.0);

    var shapeDef = zb.b2DefaultShapeDef();
    shapeDef.density = 1.0;
    shapeDef.friction = 0.3;

    _ = zb.b2CreatePolygonShape(bodyId, &shapeDef, &dynamicBox);

    const timeStep = 1.0 / 60.0;
    const subStepCount = 4;
    for (0..90) |_| {
        zb.b2World_Step(worldId, timeStep, subStepCount);
        const position = zb.b2Body_GetPosition(bodyId);
        const rotation = zb.b2Body_GetRotation(bodyId);
        std.debug.print("{d:4.2} {d:4.2} {d:4.2}\n", .{ position.x, position.y, zb.b2Rot_GetAngle(rotation) });
    }

    zb.b2DestroyWorld(worldId);
}
