package com.katasticho.erp.common.module;

import lombok.RequiredArgsConstructor;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.aop.support.AopUtils;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;

@Aspect
@Component
@RequiredArgsConstructor
public class ModuleAccessAspect {

    private final ModuleAccessService moduleAccessService;

    @Before("@within(com.katasticho.erp.common.module.RequiresModule) || @annotation(com.katasticho.erp.common.module.RequiresModule)")
    public void requireModule(JoinPoint joinPoint) {
        RequiresModule requiresModule = findAnnotation(joinPoint);
        if (requiresModule != null) {
            moduleAccessService.requireEnabled(requiresModule.value());
        }
    }

    private RequiresModule findAnnotation(JoinPoint joinPoint) {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        RequiresModule methodAnnotation = AnnotatedElementUtils.findMergedAnnotation(method, RequiresModule.class);
        if (methodAnnotation != null) {
            return methodAnnotation;
        }

        Class<?> targetClass = AopUtils.getTargetClass(joinPoint.getTarget());
        return AnnotatedElementUtils.findMergedAnnotation(targetClass, RequiresModule.class);
    }
}
